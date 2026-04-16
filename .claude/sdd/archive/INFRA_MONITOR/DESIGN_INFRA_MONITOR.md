# DESIGN: Infra Monitor Expansion

> Technical design for expanding the Cost Monitor into an Infra Monitor with dbt pipeline health and embedded documentation

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | INFRA_MONITOR |
| **Date** | 2026-04-15 |
| **Author** | design-agent |
| **DEFINE** | [DEFINE_INFRA_MONITOR.md](./DEFINE_INFRA_MONITOR.md) |
| **Status** | Ready for Build |

---

## Architecture Overview

```text
┌─ GitHub Actions ─────────────────────────────────────────────────────────────┐
│                                                                              │
│  deploy-dbt-docs.yml            deploy-streamlit-cost-monitor.yml            │
│  (on push: ammodepot/**)        (on push: streamlit_cost_monitor/**)         │
│                                                                              │
│  ┌─────────────────────┐        ┌──────────────────────────────────────────┐ │
│  │ 1. Fetch SF key     │        │ 1. snow streamlit deploy --replace       │ │
│  │    (Secrets Manager) │        │ 2. ALTER STREAMLIT ... SET EAI + secret  │ │
│  │ 2. uv + dbt deps    │        │ 3. DESCRIBE STREAMLIT (smoke test)       │ │
│  │ 3. dbt docs gen     │        └──────────────────────────────────────────┘ │
│  │    --static          │                                                     │
│  │ 4. aws s3 cp        │                                                     │
│  │    → S3 object       │                                                    │
│  └────────┬────────────┘                                                     │
│           │                                                                  │
└───────────│──────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─ S3 (existing bucket) ─────────┐
│  ammodepot-lakehouse/          │
│  ├── production2018/  (Iceberg)│
│  ├── ammuni_prod/     (Iceberg)│
│  └── dbt-docs/                 │
│      └── index.html            │   ← Browser loads directly (no EAI needed)
│          (self-contained:      │      Single file, public-read ACL
│           manifest + catalog)  │
└────────────────────────────────┘

┌─ ECS Fargate (every 10 min) ──────────────────────────────────────────────┐
│  entrypoint.sh                                                             │
│  ├── Iceberg refresh → log: ICEBERG_REFRESH_SECONDS=N                      │
│  ├── dbt build       → log: BUILD_DURATION_SECONDS=N, BUILD_DURATION_MIN=N │
│  │                     CW metric: AmmoDepot/dbt.BuildDurationMinutes       │
│  └── Build output    → log: pass/warn/error counts (ANSI colored)          │
└───────────┬──────────────────────────────────────────────────────────┬──────┘
            │ CloudWatch Metric API                                    │ CloudWatch Logs
            │ (monitoring.us-east-1.amazonaws.com)                     │ (logs.us-east-1.amazonaws.com)
            ▼                                                          ▼
┌─ Streamlit "Infra Monitor" (AD_ANALYTICS.OPS.INFRA_MONITOR) ──────────────┐
│                                                                             │
│  Page 1: Snowflake Compute     ← existing (unchanged)                       │
│  Page 2: Snowflake Storage     ← existing (unchanged)                       │
│  Page 3: AWS Infrastructure    ← existing (unchanged)                       │
│  Page 4: Combined              ← existing (unchanged)                       │
│  Page 5: dbt Pipeline          ← NEW                                        │
│    ├─ KPI row                  Last build time, duration, status             │
│    ├─ Build Duration chart     go.Scatter, 7d, 10-min ceiling hline         │
│    ├─ Build Health table       dark_dataframe, parsed from CW Logs          │
│    └─ dbt Docs                 st.components.v1.iframe → S3 static site     │
│                                                                             │
│  EAI: aws_cost_explorer_integration                                         │
│    ├── ce.us-east-1.amazonaws.com          (existing)                        │
│    ├── pypi.org + files.pythonhosted.org   (existing)                        │
│    ├── monitoring.us-east-1.amazonaws.com  (NEW)                             │
│    └── logs.us-east-1.amazonaws.com        (NEW)                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| Page 5: dbt Pipeline | Build duration chart, health table, docs iframe | Streamlit + Plotly + iframe |
| CloudWatch metrics module | Fetch BuildDurationMinutes + parse build logs | boto3 `cloudwatch` + `logs` clients |
| S3 docs object | Host self-contained dbt docs HTML | `ammodepot-lakehouse/dbt-docs/` prefix in existing S3 bucket |
| CI: docs workflow | Generate manifest + upload to S3 on model changes | GitHub Actions + uv + dbt-core |
| Bootstrap SQL | EAI egress rules for CloudWatch + Logs | Snowflake DDL |
| Rename migration | Object rename + viewer re-grants | Snowflake DDL + CI update |

---

## Key Decisions

### Decision 1: Reuse Existing AWS Credential Mechanism for CloudWatch

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-15 |

**Context:** Page 5 needs boto3 clients for CloudWatch metrics and Logs. The app already has a dual-mode credential loader for Cost Explorer (`aws_costs.py`).

**Choice:** Create `cloudwatch` and `logs` boto3 clients using the same credential mechanism — `_load_sis_creds()` in SiS, default boto3 chain locally. Factor credential loading into a shared `_get_boto3_client(service)` function.

**Rationale:** Same `svc_snowflake_costs` IAM user, same Snowflake secret. CloudWatch and Logs are read-only APIs. No new secrets or IAM users needed — just verify the existing IAM policy allows `cloudwatch:GetMetricData` and `logs:FilterLogEvents`.

**Alternatives Rejected:**
1. Separate IAM user for CloudWatch — unnecessary overhead, same trust boundary
2. CloudWatch embedded dashboards — require signed URLs, can't customize appearance

**Consequences:**
- Must verify `svc_snowflake_costs` IAM policy includes CloudWatch + Logs read permissions (Assumption A-007)
- Single credential failure affects all AWS pages (existing behavior — acceptable)

---

### Decision 2: Log Parsing Contract with entrypoint.sh

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-15 |

**Context:** Build health data (status, pass/warn/error counts, Iceberg refresh time) is only available in CloudWatch Logs, not as structured metrics. Need to extract it via log parsing.

**Choice:** Parse CloudWatch Logs `/ecs/ammodepot-dbt` using regex patterns matching the structured markers already emitted by `entrypoint.sh`:

| Marker | Pattern | Example |
|--------|---------|---------|
| Build duration | `BUILD_DURATION_SECONDS=(\d+)` | `BUILD_DURATION_SECONDS=191` |
| Build duration (min) | `BUILD_DURATION_MINUTES=(\d+\.\d+)` | `BUILD_DURATION_MINUTES=3.18` |
| Iceberg refresh | `ICEBERG_REFRESH_SECONDS=(\d+)` | `ICEBERG_REFRESH_SECONDS=23` |
| Build status | Presence of `\[31mERROR` in log stream | ANSI red = error |
| dbt results | `Done\. PASS=(\d+) WARN=(\d+) ERROR=(\d+)` | `Done. PASS=363 WARN=11 ERROR=0` |

**Rationale:** These markers are already stable (in production since ECS launch). Parsing is simpler than adding new CloudWatch custom metrics for each field.

**Alternatives Rejected:**
1. Publish all fields as CloudWatch custom metrics — adds cost ($0.30/metric/month) and complexity to entrypoint
2. Write to a Snowflake table from ECS — adds Snowflake write dependency to the build process

**Consequences:**
- If `entrypoint.sh` log format changes, the parser breaks — document the contract in code comments
- CloudWatch Logs `FilterLogEvents` costs $0.005/GB scanned — negligible for our log volume
- Parse the dbt summary line for pass/warn/error; look at exit patterns for build status

---

### Decision 3: Reuse Existing `ammodepot-lakehouse` S3 Bucket

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-15 |

**Context:** dbt docs need to be accessible via URL for iframe embedding. With `--static`, the output is a single self-contained HTML file — no multi-file hosting needed.

**Choice:** Upload `static_index.html` to `s3://ammodepot-lakehouse/dbt-docs/index.html` with public-read ACL. Reuse the existing Iceberg lakehouse bucket — no new bucket creation. The iframe points directly to the S3 object URL: `https://ammodepot-lakehouse.s3.us-east-1.amazonaws.com/dbt-docs/index.html`.

**Rationale:** The `ammodepot-lakehouse` bucket already exists, `svc_iac` already has write access, and the Iceberg data lives in separate prefixes (`production2018/`, `ammuni_prod/`). A `dbt-docs/` prefix provides clean separation. No new infrastructure to create or manage.

**Alternatives Rejected:**
1. New dedicated bucket — unnecessary infra when existing bucket has capacity and access
2. CloudFront + OAI — over-engineering for an internal tool with 2-3 users
3. Snowflake stage — can't serve as a URL for iframe

**Consequences:**
- Single object is publicly readable (anyone with the URL can view) — mitigated by non-obvious path prefix
- S3 object URL stored as a config constant, not hardcoded in page code
- No new IAM permissions needed — `svc_iac` already has bucket access
- No new bucket creation — removes Assumption A-002 entirely

---

### Decision 4: Full `dbt docs generate --static` with Snowflake Creds in CI

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-15 |

**Context:** CI needs to generate the dbt docs site. The default output is a multi-file site (index.html + manifest.json + catalog.json) that requires a web server or S3 static website hosting to serve.

**Choice:** Run `dbt docs generate --static --profiles-dir . --target prod` in CI to produce a single self-contained `static_index.html` (4.3 MB) with full manifest AND catalog data embedded inline. Upload this one file to S3. Reuse existing Snowflake creds from Secrets Manager (`ammodepot/dbt/snowflake`) — same pattern as `deploy-streamlit-cost-monitor.yml`.

**Rationale:**
- `--static` (available since dbt-core 1.7.0, our version is 1.11.6+) embeds all JSON data into `static_index.html` — no multi-file serving needed
- **Full catalog** includes column types and row counts — strictly better than manifest-only
- Snowflake creds are NOT new to CI — the Streamlit deploy workflow already fetches the SF private key from Secrets Manager. Reusing the same pattern adds zero secret management overhead
- **Validated locally:** `dbt docs generate --static` on dbt-core 1.11.6 produces a valid 4.3 MB `static_index.html` with manifest + catalog embedded
- Single `aws s3 cp` replaces `aws s3 sync`
- ~10s catalog query against Snowflake — negligible CI time

**Alternatives Rejected:**
1. `--static --no-compile` (manifest-only) — originally planned to avoid SF creds in CI, but `--no-compile` still fails without env vars from profiles.yml. Since creds are already available in CI, there's no reason to skip the catalog
2. Multi-file `dbt docs generate` — requires S3 static website hosting to serve multiple files
3. Custom static site generator — reinvents dbt docs, loses DAG/search features

**Consequences:**
- Full docs experience: DAG, model descriptions, column types, row counts, test definitions, source freshness
- S3 bucket does NOT need static website hosting — just public-read on a single object
- CI reuses existing Secrets Manager fetch pattern (5 lines of YAML copied from Streamlit deploy)
- CI needs `uv` + `dbt-core` + `dbt-snowflake` installed + Snowflake env vars set

---

### Decision 5: Rename Object via CI Deploy (Not DDL Migration)

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-15 |

**Context:** Renaming from `COST_MONITOR` to `INFRA_MONITOR` requires changing the Snowflake object. Two approaches: DDL `ALTER STREAMLIT RENAME` or deploy new + drop old.

**Choice:** Update `snowflake.yml` identifier to `infra_monitor`, let CI `snow streamlit deploy --replace` create the new object. Run a one-time bootstrap SQL to drop the old object and re-grant viewer access.

**Rationale:** `snow streamlit deploy --replace` already handles object creation. A DDL rename would require verifying that `ALTER STREAMLIT RENAME` exists and works with EAI bindings (untested). Deploy-new-then-drop-old is the safer path.

**Alternatives Rejected:**
1. `ALTER STREAMLIT RENAME` — may not carry over EAI/secret bindings; undocumented edge cases
2. Keep old name, just rename display — inconsistent naming carried forever

**Consequences:**
- Brief gap between old object drop and new object deploy (seconds, in CI)
- Viewer bookmarks break once (one-time)
- Must re-run viewer grants on the new object name

---

## File Manifest

| # | File | Action | Purpose | Agent | Dependencies |
|---|------|--------|---------|-------|--------------|
| 1 | `streamlit_cost_monitor/utils/config.py` | Modify | Add CloudWatch constants + S3 docs URL | @streamlit-expert | None |
| 2 | `streamlit_cost_monitor/utils/cloudwatch_metrics.py` | Create | boto3 CloudWatch + Logs client with cached queries | @streamlit-expert | 1 |
| 3 | `streamlit_cost_monitor/pages/5_dbt_Pipeline.py` | Create | Page 5: KPI row, duration chart, health table, docs iframe | @streamlit-expert | 1, 2 |
| 4 | `streamlit_cost_monitor/streamlit_app.py` | Modify | Rename title/description to "Infra Monitor" | @streamlit-expert | None |
| 5 | `streamlit_cost_monitor/app.py` | Modify | Rename title/description to "Infra Monitor" (local) | @streamlit-expert | None |
| 6 | `streamlit_cost_monitor/snowflake.yml` | Modify | Change identifier to `infra_monitor`, update title | @streamlit-expert | None |
| 7 | `streamlit_cost_monitor/setup/05_add_cloudwatch_egress.sql` | Create | EAI update: add CloudWatch + Logs network rules | @snowflake-expert | None |
| 8 | `streamlit_cost_monitor/setup/06_rename_and_grant.sql` | Create | Drop old object, re-grant viewers on new name | @snowflake-expert | None |
| 9 | `.github/workflows/deploy-streamlit-cost-monitor.yml` | Modify | Update object name in EAI re-attach + smoke test | @ci-cd-specialist | 6 |
| 10 | `.github/workflows/deploy-dbt-docs.yml` | Create | CI: dbt parse + docs generate + S3 upload | @ci-cd-specialist | None |
| 11 | `streamlit_cost_monitor/utils/aws_costs.py` | Modify | Extract shared credential loader for reuse by cloudwatch module | @streamlit-expert | None |

**Total Files:** 11 (4 create, 7 modify)

---

## Agent Assignment Rationale

| Agent | Files Assigned | Why This Agent |
|-------|----------------|----------------|
| @streamlit-expert | 1, 2, 3, 4, 5, 6, 11 | SiS compatibility, Plotly dark theme, dual-mode patterns, container runtime |
| @snowflake-expert | 7, 8 | EAI network rules, RBAC grants, Snowflake DDL |
| @ci-cd-specialist | 9, 10 | GitHub Actions workflows, S3 upload, path-filtered triggers |

---

## Code Patterns

### Pattern 1: Shared boto3 Client Factory (aws_costs.py refactor)

```python
# utils/aws_costs.py — extract credential loading for reuse

@st.cache_resource
def _get_boto3_client(service: str):
    """Return a boto3 client for any AWS service using the right credential source.
    
    SiS: credentials from Snowflake secret via env var.
    Local: default boto3 chain (AWS_PROFILE=ammodepot).
    """
    import boto3
    if is_sis():
        creds = _load_sis_creds()
        return boto3.client(
            service,
            aws_access_key_id=creds.access_key,
            aws_secret_access_key=creds.secret_key,
            region_name="us-east-1",
        )
    return boto3.client(service, region_name="us-east-1")


def get_ce_client():
    """Cost Explorer client (backward-compatible wrapper)."""
    return _get_boto3_client("ce")
```

### Pattern 2: CloudWatch Metric Query

```python
# utils/cloudwatch_metrics.py

@st.cache_data(ttl=300, show_spinner=False)  # 5-min cache — metric updates every ~10 min
def build_duration_timeseries(days: int = 7) -> pd.DataFrame:
    """Fetch BuildDurationMinutes from CloudWatch for the last N days."""
    client = _get_boto3_client("cloudwatch")
    end = datetime.utcnow()
    start = end - timedelta(days=days)
    
    resp = client.get_metric_data(
        MetricDataQueries=[{
            "Id": "duration",
            "MetricStat": {
                "Metric": {
                    "Namespace": CW_NAMESPACE,
                    "MetricName": CW_METRIC_NAME,
                },
                "Period": 600,  # 10-min aligned with EventBridge schedule
                "Stat": "Average",
            },
            "ReturnData": True,
        }],
        StartTime=start,
        EndTime=end,
        ScanBy="TimestampAscending",
    )
    
    values = resp["MetricDataResults"][0]
    return pd.DataFrame({
        "timestamp": values["Timestamps"],
        "duration_min": values["Values"],
    })
```

### Pattern 3: CloudWatch Logs Parsing

```python
# utils/cloudwatch_metrics.py

@st.cache_data(ttl=300, show_spinner=False)
def recent_builds(limit: int = 25) -> pd.DataFrame:
    """Parse recent dbt builds from CloudWatch Logs.
    
    Each ECS task run is a log stream. We fetch the most recent streams
    and extract structured markers from each.
    """
    client = _get_boto3_client("logs")
    
    # Get recent log streams (one per ECS task invocation)
    streams_resp = client.describe_log_streams(
        logGroupName=CW_LOG_GROUP,
        orderBy="LastEventTime",
        descending=True,
        limit=limit,
    )
    
    builds = []
    for stream in streams_resp.get("logStreams", []):
        events = client.get_log_events(
            logGroupName=CW_LOG_GROUP,
            logStreamName=stream["logStreamName"],
            startFromHead=True,
        )
        text = "\n".join(e["message"] for e in events.get("events", []))
        builds.append(_parse_build_log(text, stream))
    
    return pd.DataFrame(builds)


def _parse_build_log(text: str, stream: dict) -> dict:
    """Extract structured markers from a single build log.
    
    CONTRACT: These patterns match markers emitted by ecs/entrypoint.sh.
    If the entrypoint format changes, update these patterns.
    """
    import re
    
    ts = datetime.fromtimestamp(
        stream.get("lastEventTimestamp", 0) / 1000
    )
    
    duration = _extract(r"BUILD_DURATION_MINUTES=(\d+\.\d+)", text)
    iceberg = _extract(r"ICEBERG_REFRESH_SECONDS=(\d+)", text)
    
    # dbt summary line: "Done. PASS=363 WARN=11 ERROR=0"
    pass_count = _extract(r"PASS=(\d+)", text)
    warn_count = _extract(r"WARN=(\d+)", text)
    error_count = _extract(r"ERROR=(\d+)", text)
    
    # Build failed if ANSI red ERROR present or error_count > 0
    has_error = "\x1b[31mERROR" in text or (error_count and float(error_count) > 0)
    
    return {
        "Timestamp": ts.strftime("%Y-%m-%d %H:%M"),
        "Status": "FAIL" if has_error else "PASS",
        "Duration (min)": float(duration) if duration else None,
        "Iceberg (s)": int(float(iceberg)) if iceberg else None,
        "Pass": int(float(pass_count)) if pass_count else None,
        "Warn": int(float(warn_count)) if warn_count else None,
        "Error": int(float(error_count)) if error_count else None,
    }


def _extract(pattern: str, text: str) -> str | None:
    m = re.search(pattern, text)
    return m.group(1) if m else None
```

### Pattern 4: Page 5 Layout

```python
# pages/5_dbt_Pipeline.py

import streamlit as st
import plotly.graph_objects as go

from utils.chart_theme import ACCENT, DANGER, WARNING, apply_theme, dark_dataframe, kpi_card
from utils.cloudwatch_metrics import build_duration_timeseries, recent_builds
from utils.config import CW_BUILD_CEILING_MIN, DBT_DOCS_URL

st.set_page_config(page_title="dbt Pipeline", layout="wide")
st.title("dbt Pipeline")
st.caption(
    "Build duration from CloudWatch metric `AmmoDepot/dbt.BuildDurationMinutes`. "
    "Build health parsed from CloudWatch Logs `/ecs/ammodepot-dbt`."
)

# --- KPI row ---
builds = recent_builds()
if not builds.empty:
    last = builds.iloc[0]
    k1, k2, k3, k4 = st.columns(4)
    with k1:
        kpi_card("Last Build", last["Timestamp"])
    with k2:
        kpi_card("Status", last["Status"])
    with k3:
        dur = last["Duration (min)"]
        kpi_card("Duration", f"{dur:.1f} min" if dur else "—")
    with k4:
        kpi_card("Headroom", f"{CW_BUILD_CEILING_MIN - dur:.1f} min" if dur else "—")
    st.divider()

# --- Duration chart ---
st.subheader("Build Duration (7d)")
df = build_duration_timeseries(days=7)
if df.empty:
    st.info("No build duration data available.")
else:
    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=df["timestamp"].tolist(),
        y=df["duration_min"].tolist(),
        mode="lines+markers",
        name="Build Duration",
        marker=dict(size=4),
        line=dict(color=ACCENT),
        hovertemplate="%{x|%b %d %H:%M}<br>%{y:.1f} min<extra></extra>",
    ))
    # 10-min ceiling reference line
    fig.add_hline(
        y=CW_BUILD_CEILING_MIN, line_dash="dash", line_color=DANGER,
        annotation_text=f"{CW_BUILD_CEILING_MIN}-min ceiling",
        annotation_position="top left",
        annotation_font_color=DANGER,
    )
    fig.update_yaxes(title_text="Minutes", rangemode="tozero")
    apply_theme(fig, height=350)
    st.plotly_chart(fig, use_container_width=True, theme=None)

st.divider()

# --- Build health table ---
st.subheader("Recent Builds")
if builds.empty:
    st.info("No build logs available.")
else:
    dark_dataframe(builds, height=400)

st.divider()

# --- dbt Docs iframe ---
st.subheader("dbt Documentation")
st.caption("Interactive model lineage, descriptions, and test definitions.")
try:
    import streamlit.components.v1 as components
    components.iframe(DBT_DOCS_URL, height=700, scrolling=True)
except Exception:
    st.info(
        "dbt docs not available. Ensure the CI workflow has deployed "
        "the static site to S3."
    )
```

### Pattern 5: Config Constants

```python
# utils/config.py — additions

# CloudWatch — dbt build metrics
CW_NAMESPACE: str = "AmmoDepot/dbt"
CW_METRIC_NAME: str = "BuildDurationMinutes"
CW_LOG_GROUP: str = "/ecs/ammodepot-dbt"
CW_BUILD_CEILING_MIN: float = 10.0
CW_METRIC_LOOKBACK_DAYS: int = 7

# S3 — dbt docs (single static_index.html via --static flag)
DBT_DOCS_URL: str = "https://ammodepot-lakehouse.s3.us-east-1.amazonaws.com/dbt-docs/index.html"
```

### Pattern 6: EAI Update SQL

```sql
-- setup/05_add_cloudwatch_egress.sql
use role accountadmin;

-- Network rule for CloudWatch metrics + logs APIs
create or replace network rule ad_analytics.ops.cloudwatch_rule
    type = host_port
    mode = egress
    value_list = (
        'monitoring.us-east-1.amazonaws.com',
        'logs.us-east-1.amazonaws.com'
    )
    comment = 'Egress to CloudWatch Metrics + Logs for dbt pipeline monitoring';

grant usage on network rule ad_analytics.ops.cloudwatch_rule
    to role streamlit_role;

-- Rebuild EAI with all three rules (CE + PyPI + CloudWatch)
create or replace external access integration aws_cost_explorer_integration
    allowed_network_rules = (
        ad_analytics.ops.aws_cost_explorer_rule,
        ad_analytics.ops.pypi_rule,
        ad_analytics.ops.cloudwatch_rule
    )
    allowed_authentication_secrets = (ad_analytics.ops.aws_cost_explorer_creds)
    enabled = true
    comment = 'Infra monitor → AWS Cost Explorer + PyPI + CloudWatch';

grant usage on integration aws_cost_explorer_integration
    to role streamlit_role;
```

### Pattern 7: CI Docs Workflow

```yaml
# .github/workflows/deploy-dbt-docs.yml
name: Deploy dbt Docs to S3

on:
  push:
    branches: [main]
    paths:
      - 'ammodepot/**'
      - '.github/workflows/deploy-dbt-docs.yml'
  workflow_dispatch:

jobs:
  deploy-docs:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    env:
      SNOWFLAKE_ACCOUNT: iwb48385.us-east-1
      SNOWFLAKE_USER: SVC_DBT
      SNOWFLAKE_ROLE: TRANSFORMER_ROLE
      SNOWFLAKE_WAREHOUSE: ETL_WH
      SNOWFLAKE_DATABASE: AD_ANALYTICS

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      # Reuse same Secrets Manager key as Streamlit deploy + ECS
      - name: Fetch Snowflake private key from Secrets Manager
        run: |
          set -euo pipefail
          aws secretsmanager get-secret-value \
            --secret-id ammodepot/dbt/snowflake \
            --query SecretString --output text > /tmp/sf_secret.json
          python3 <<'PY'
          import json, os, pathlib
          with open("/tmp/sf_secret.json") as f:
              d = json.load(f)
          key_path = pathlib.Path("/tmp/sf_rsa_key.p8")
          key_path.write_text(d["SNOWFLAKE_PRIVATE_KEY"])
          key_path.chmod(0o600)
          passphrase = d.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE", "") or ""
          if passphrase:
              print(f"::add-mask::{passphrase}")
          with open(os.environ["GITHUB_ENV"], "a") as env:
              env.write("SNOWFLAKE_PRIVATE_KEY_PATH=/tmp/sf_rsa_key.p8\n")
              if passphrase:
                  env.write(f"SNOWFLAKE_PRIVATE_KEY_PASSPHRASE={passphrase}\n")
          PY
          rm /tmp/sf_secret.json

      - name: Install uv
        uses: astral-sh/setup-uv@v4

      - name: Install dbt + generate static docs
        working-directory: ammodepot
        run: |
          uv sync
          uv run dbt deps --profiles-dir .
          uv run dbt docs generate --static --profiles-dir . --target prod

      - name: Upload static docs to S3
        run: |
          aws s3 cp ammodepot/target/static_index.html \
            s3://ammodepot-lakehouse/dbt-docs/index.html \
            --content-type "text/html" \
            --cache-control "max-age=300" \
            --acl public-read
```

### Pattern 8: Rename + Grant SQL

```sql
-- setup/06_rename_and_grant.sql
-- Run ONCE after first deploy with new name. Idempotent.
use role accountadmin;

-- Drop old object (if exists — safe to re-run)
drop streamlit if exists ad_analytics.ops.cost_monitor;

-- Re-grant viewer access on new object
grant usage on streamlit ad_analytics.ops.infra_monitor
    to role dashboard_viewer_role;
grant usage on streamlit ad_analytics.ops.infra_monitor
    to role powerbi_readonly_role;

-- Verify
describe streamlit ad_analytics.ops.infra_monitor;
```

---

## Data Flow

```text
1. ECS Fargate runs dbt build every 10 min
   │
   ├── Publishes BuildDurationMinutes → CloudWatch Metric (AmmoDepot/dbt)
   └── Logs build output → CloudWatch Logs (/ecs/ammodepot-dbt)
       Contains: ICEBERG_REFRESH_SECONDS, BUILD_DURATION_*, PASS/WARN/ERROR

2. User opens Page 5 in Streamlit
   │
   ├── cloudwatch_metrics.build_duration_timeseries()
   │   └── boto3 cloudwatch.get_metric_data() → DataFrame
   │       └── Cached 5 min (metric publishes every ~10 min)
   │
   ├── cloudwatch_metrics.recent_builds()
   │   └── boto3 logs.describe_log_streams() + get_log_events() → DataFrame
   │       └── Regex parse structured markers → status/duration/iceberg/pass/warn/error
   │       └── Cached 5 min
   │
   └── iframe loads DBT_DOCS_URL
       └── Browser fetches S3 static site directly (no server-side call)

3. Developer pushes model changes to main
   │
   └── GitHub Actions: deploy-dbt-docs.yml
       ├── Fetch SF private key from Secrets Manager (reuses ECS/Streamlit pattern)
       ├── dbt docs generate --static → static_index.html (4.3 MB)
       │   (self-contained: manifest + full catalog with column types/row counts)
       └── aws s3 cp → S3 object (public-read, no website hosting)
```

---

## Integration Points

| External System | Integration Type | Authentication | Endpoint |
|-----------------|-----------------|----------------|----------|
| CloudWatch Metrics | boto3 SDK (`get_metric_data`) | IAM key-pair via Snowflake secret | `monitoring.us-east-1.amazonaws.com` |
| CloudWatch Logs | boto3 SDK (`describe_log_streams`, `get_log_events`) | IAM key-pair via Snowflake secret | `logs.us-east-1.amazonaws.com` |
| AWS Cost Explorer | boto3 SDK (existing) | IAM key-pair via Snowflake secret | `ce.us-east-1.amazonaws.com` |
| S3 dbt Docs | Browser iframe (no server call) | Public-read S3 object | `ammodepot-lakehouse.s3.us-east-1.amazonaws.com/dbt-docs/index.html` |
| S3 Upload (CI) | AWS CLI (`aws s3 cp`) | GitHub Actions secrets | `s3.us-east-1.amazonaws.com` |

---

## Testing Strategy

| Test Type | Scope | Method | Coverage Goal |
|-----------|-------|--------|---------------|
| Manual: SiS | All 5 pages render in SiS container runtime | `snow streamlit deploy` + open in Snowsight | AT-001 through AT-009, AT-012 |
| Manual: Local | Page 5 renders with local boto3 + S3 URL | `streamlit run app.py` | AT-014 |
| CI smoke test | Streamlit object exists + has correct EAI | `describe streamlit` in CI | AT-013 |
| CI docs | Docs upload succeeds, S3 site accessible | Workflow run + curl check | AT-010, AT-011 |
| Log parser | Regex patterns match real CloudWatch log samples | Manual: compare parsed output to raw log | AT-006, AT-007 |
| Regression | Pages 1-4 unchanged | Visual comparison before/after deploy | AT-012 |

---

## Error Handling

| Error Type | Handling Strategy | Retry? |
|------------|-------------------|--------|
| CloudWatch API failure (credentials, permissions) | `try/except` → `st.error()` with diagnostic message; page continues showing other sections | No |
| CloudWatch returns empty data (new metric, no builds) | `st.info("No data available")` placeholder | No |
| Log stream has no structured markers (format change) | Return `None` for unparsed fields; row shows in table with blanks | No |
| S3 docs site unreachable | `try/except` around `components.iframe()` → `st.info("dbt docs not yet deployed")` | No |
| EAI not attached (post-deploy race) | CloudWatch calls fail → falls through to error handling above | No |

---

## Configuration

| Config Key | Type | Default | Description |
|------------|------|---------|-------------|
| `CW_NAMESPACE` | str | `"AmmoDepot/dbt"` | CloudWatch namespace for dbt metrics |
| `CW_METRIC_NAME` | str | `"BuildDurationMinutes"` | Metric name published by entrypoint.sh |
| `CW_LOG_GROUP` | str | `"/ecs/ammodepot-dbt"` | CloudWatch log group for ECS dbt tasks |
| `CW_BUILD_CEILING_MIN` | float | `10.0` | EventBridge schedule ceiling (reference line) |
| `CW_METRIC_LOOKBACK_DAYS` | int | `7` | Default lookback for duration chart |
| `DBT_DOCS_URL` | str | `"https://ammodepot-lakehouse.s3.us-east-1.amazonaws.com/dbt-docs/index.html"` | S3 object URL for self-contained dbt docs |

---

## Security Considerations

- **S3 docs object**: single `index.html` with public-read ACL. Contains only schema metadata (model names, descriptions, test definitions). No business data, no credentials. Bucket itself remains private — only the single object is publicly readable.
- **AWS credentials**: Same `svc_snowflake_costs` IAM user — verify least-privilege for CloudWatch + Logs read-only actions. No new secrets introduced.
- **CloudWatch Logs**: May contain dbt SQL compilation output. `get_log_events` only reads, never writes. Access scoped to `/ecs/ammodepot-dbt` log group.
- **iframe**: Loads from S3 in the user's browser. No cross-origin data leakage risk — dbt docs is a self-contained static site.

---

## Observability

| Aspect | Implementation |
|--------|----------------|
| Logging | Streamlit's built-in logging; errors surfaced via `st.error()` on the page |
| Metrics | Build duration chart IS the observability — the tool monitors itself |
| Cost | CloudWatch API: `GetMetricData` ~$0.01/1000 requests; `FilterLogEvents` ~$0.005/GB. With 5-min cache + ~10 views/day ≈ $0.02/month |

---

## Pre-Build Validation Checklist

Before starting build phase, verify these assumptions:

- [ ] **A-001**: `svc_snowflake_costs` IAM policy allows `cloudwatch:GetMetricData`, `cloudwatch:DescribeAlarms` (read), `logs:DescribeLogStreams`, `logs:GetLogEvents` (read)
- [x] **A-002**: ~~S3 bucket creation~~ — eliminated. Reusing existing `ammodepot-lakehouse` bucket with `dbt-docs/` prefix
- [x] **A-005**: `dbt docs generate --static` produces a functional 4.3 MB `static_index.html` on dbt-core 1.11.6 (validated locally 2026-04-15; full catalog included)
- [ ] **A-006**: S3 object URL reachable from corporate network / VPN
- [ ] **A-007**: `svc_snowflake_costs` IAM policy needs CloudWatch + Logs read permissions added. Current policy is `CostExplorerReadOnly` with only `ce:*` actions. Must add: `cloudwatch:GetMetricData`, `logs:DescribeLogStreams`, `logs:GetLogEvents`. **Verified 2026-04-15 — update required before build.**

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-15 | design-agent | Initial version |
| 1.1 | 2026-04-15 | design-agent | Adopted `--static` flag: single self-contained HTML, no S3 website hosting needed |
| 1.2 | 2026-04-15 | design-agent | Full catalog: dropped `--no-compile`, reuse existing SF creds in CI. Validated `--static` locally (4.3 MB). IAM policy update needed for `svc_snowflake_costs` (CloudWatch + Logs read) |
| 1.3 | 2026-04-15 | design-agent | Reuse `ammodepot-lakehouse` bucket instead of creating new one. Eliminates A-002. Fixed S3 URLs |

---

## Next Step

**Ready for:** `/build .claude/sdd/features/DESIGN_INFRA_MONITOR.md`
