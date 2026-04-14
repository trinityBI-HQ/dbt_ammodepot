# DESIGN: SiS Container Runtime Migration

> Technical design for migrating `streamlit_app/` to container runtime with full feature parity and FinOps attribution.

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | SIS_CONTAINER_MIGRATION |
| **Date** | 2026-04-14 |
| **Author** | design-agent |
| **DEFINE** | [DEFINE_SIS_CONTAINER_MIGRATION.md](./DEFINE_SIS_CONTAINER_MIGRATION.md) |
| **Status** | Ready for Build |

---

## Architecture Overview

```text
Before (warehouse runtime):
┌──────────────────────────────────┐
│  streamlit_app/                  │
│  environment.yml (conda, 1.26)  │
│  No compute pool                │
│  No EAI                         │
│  _is_sis guards → degraded UX   │
└──────────┬───────────────────────┘
           │ Shared warehouse runtime
           ▼
     ┌──────────┐     ┌──────────┐
     │COMPUTE_WH│     │ st.map() │  ← degraded maps
     └──────────┘     │ no clicks│  ← disabled cross-filter
                      └──────────┘

After (container runtime):
┌──────────────────────────────────────────────────┐
│  streamlit_app/                                  │
│  snowflake.yml  → container runtime (1.55+)      │
│  requirements.txt (pip)                          │
│  setup/01_bootstrap.sql (pool, EAI, tags)        │
└──────────┬───────────────────────────────────────┘
           │
     ┌─────┴──────┐
     │sales_dash-  │     ┌──────────────────────┐
     │board_pool   │     │sales_dashboard_      │
     │CPU_X64_XS   │     │integration (EAI)     │
     │auto-sus 300s│     │├─ CARTO tiles egress  │
     │tagged       │     │├─ pypi.org egress     │
     └─────┬───────┘     │└─ pythonhosted egress │
           │             └──────────┬────────────┘
           ▼                        │
     ┌──────────┐    ┌──────────────▼──────────┐
     │COMPUTE_WH│    │ Scattermapbox + on_select│ ← full parity
     └──────────┘    │ CARTO dark tiles         │
                     │ chart click filtering    │
                     └──────────────────────────┘

CI/CD:
  push streamlit_app/** → GitHub Actions
    → snow streamlit deploy --replace
    → ALTER STREAMLIT SET EAI (re-attach)
    → DESCRIBE STREAMLIT (smoke test)
```

---

## Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| `snowflake.yml` | Declare app entity, runtime, pool, warehouse | Snowflake CLI v2 definition |
| `requirements.txt` | Pip dependencies for container runtime | pip (replaces conda environment.yml) |
| `setup/01_bootstrap.sql` | One-time infra: pool, EAI, network rules, stage, grants, tags | Snowflake SQL (ACCOUNTADMIN) |
| `deploy-streamlit-dashboard.yml` | CI/CD: deploy + EAI re-attach + smoke test | GitHub Actions |
| Page 1 modifications | Remove 2 `_is_sis` guards (chart clicks + maps) | Python / Streamlit |
| Page 2 modifications | Remove 2 `_is_sis` guards (chart clicks + maps) | Python / Streamlit |

---

## Key Decisions

### Decision 1: Dedicated Compute Pool (not shared)

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-14 |

**Context:** The BI dashboard needs a compute pool for container runtime. The cost monitor already has `cost_monitor_pool`.

**Choice:** Create `sales_dashboard_pool` (CPU_X64_XS, 1 node, auto-suspend 300s).

**Rationale:** Clean FinOps attribution — each Streamlit app gets its own tagged pool. Isolates workloads so one app can't starve the other.

**Alternatives Rejected:**
1. Shared `cost_monitor_pool` — muddied cost attribution, contention risk
2. Larger instance family — overkill for current user base

**Consequences:**
- ~$5/mo incremental cost (acceptable)
- Clean per-app cost reporting via `GOVERNANCE.TAGS`

---

### Decision 2: Remove All _is_sis Rendering Guards

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-14 |

**Context:** Four `_is_sis` guard locations in Pages 1 and 2 disable chart click selection and degrade maps in SiS. Streamlit 1.55+ (container runtime) supports both features.

**Choice:** Remove all 4 guards, making SiS and local dev render identically. Keep `_is_sis` in `utils/db.py` for session/connection dual-mode.

**Rationale:** The guards exist solely because warehouse runtime's Streamlit 1.26 lacks these features. Container runtime provides 1.55+ where both `on_select` and Scattermapbox work. The `not callable(sel)` safety check in chart click handlers already protects against the old warehouse runtime bug.

**Alternatives Rejected:**
1. Keep guards (phased approach) — delays value, two deploy cycles for one logical change
2. Add feature detection instead of `_is_sis` — over-engineering; the runtime is known at deploy time

**Consequences:**
- Chart click cross-filtering enabled in SiS
- Plotly Scattermapbox with CARTO dark tiles in SiS
- CARTO tiles require EAI egress rule (handled by dedicated EAI)
- Assumption A-006 to verify: `event.selection` returns data object in container runtime

---

### Decision 3: Dedicated EAI with CARTO + PyPI Scope

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-14 |

**Context:** Container runtime needs PyPI for package installation. Scattermapbox needs CARTO CDN for map tiles.

**Choice:** Create `sales_dashboard_integration` EAI with two network rules: one for CARTO (`basemaps.cartocdn.com`), one for PyPI (`pypi.org`, `files.pythonhosted.org`).

**Rationale:** Per-app EAI is a FinOps best practice. The cost monitor's EAI is scoped to AWS Cost Explorer + PyPI — broadening it would violate least-privilege.

**Alternatives Rejected:**
1. Broaden `aws_cost_explorer_integration` — scope creep, mixes AWS API access with map tiles
2. Skip EAI, use `st.map()` — defeats the purpose of the migration

**Consequences:**
- CARTO tiles require network validation (assumption A-002: may need additional CDN domains)
- PyPI rule is a known-working pattern from cost monitor

---

### Decision 4: Template from Cost Monitor (not greenfield)

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-14 |

**Context:** Need `snowflake.yml`, `requirements.txt`, bootstrap SQL, and CI/CD workflow.

**Choice:** Clone structure from `streamlit_cost_monitor/`, adapt identifiers and scopes.

**Rationale:** Proven 5-day-old pattern in same repo. Same Snowflake account, same CI/CD infrastructure (`SVC_DBT` key-pair, Secrets Manager, ECR). Minimizes risk.

**Alternatives Rejected:**
1. Greenfield design — unnecessary when a working template exists
2. Terraform-based provisioning — SQL scripts match existing pattern, no Terraform in project

**Consequences:**
- Consistent deployment patterns across all Streamlit apps
- Known `--replace` + EAI re-attach workaround already handled

---

## File Manifest

| # | File | Action | Purpose | Agent | Dependencies |
|---|------|--------|---------|-------|--------------|
| 1 | `streamlit_app/snowflake.yml` | Create | Container runtime deployment config | @streamlit-expert | None |
| 2 | `streamlit_app/requirements.txt` | Create | Pip dependencies | @streamlit-expert | None |
| 3 | `streamlit_app/setup/01_bootstrap.sql` | Create | ACCOUNTADMIN: pool, EAI, rules, stage, grants, tags | @snowflake-expert | None |
| 4 | `.github/workflows/deploy-streamlit-dashboard.yml` | Create | CI/CD: deploy + EAI re-attach + smoke test | @ci-cd-specialist | 1, 3 |
| 5 | `streamlit_app/pages/1_Today_Yesterday.py` | Modify | Remove `_is_sis` chart click guard (line ~809) | @streamlit-expert | None |
| 6 | `streamlit_app/pages/1_Today_Yesterday.py` | Modify | Remove `_is_sis` map guard (lines ~1308-1345) | @streamlit-expert | None |
| 7 | `streamlit_app/pages/2_Sales_Overview.py` | Modify | Remove `_is_sis` chart click guard (line ~723) | @streamlit-expert | None |
| 8 | `streamlit_app/pages/2_Sales_Overview.py` | Modify | Remove `_is_sis` map guard (lines ~1460-1494) | @streamlit-expert | None |
| 9 | `streamlit_app/environment.yml` | Delete | Replaced by requirements.txt | (general) | 2 |

**Total Files:** 9 actions (4 create, 4 modify, 1 delete)

---

## Agent Assignment Rationale

| Agent | Files Assigned | Why This Agent |
|-------|----------------|----------------|
| @streamlit-expert | 1, 2, 5, 6, 7, 8 | SiS container runtime patterns, Plotly chart handling, dual-mode removal |
| @snowflake-expert | 3 | Compute pool, EAI, network rules, FinOps tagging SQL |
| @ci-cd-specialist | 4 | GitHub Actions workflow, Snowflake CLI deploy, secret management |
| (general) | 9 | Simple file deletion |

---

## Code Patterns

### Pattern 1: snowflake.yml (container runtime)

```yaml
# streamlit_app/snowflake.yml
# Cloned from streamlit_cost_monitor/snowflake.yml, adapted identifiers.
definition_version: 2

entities:
  sales_dashboard:
    type: streamlit
    identifier:
      name: sales_dashboard
      schema: ops
      database: ad_analytics
    title: "Ammunition Depot Sales Dashboard"
    main_file: streamlit_app.py

    # Container runtime (GA 2026-03-09) — Streamlit 1.55+, full PyPI, EAI egress
    runtime_name: "SYSTEM$ST_CONTAINER_RUNTIME_PY3_11"
    compute_pool: sales_dashboard_pool
    query_warehouse: compute_wh

    stage: sales_dashboard_stage
    pages_dir: pages/
    artifacts:
      - streamlit_app.py
      - requirements.txt
      - pages/
      - utils/
      - AmmoDepot.png
      - .streamlit/
```

### Pattern 2: requirements.txt

```text
# streamlit_app/requirements.txt
# SiS container runtime — pip install. Pin floors matching cost monitor.
streamlit>=1.55
pandas>=2.0
plotly>=5.22
snowflake-snowpark-python>=1.20
```

### Pattern 3: Bootstrap SQL (setup/01_bootstrap.sql)

```sql
-- streamlit_app/setup/01_bootstrap.sql
-- Run ONCE as ACCOUNTADMIN. Idempotent — safe to re-run.
--
-- Creates:
--   1. Stage for uploading Streamlit source files
--   2. Compute pool (CPU_X64_XS, 1 node, auto-suspend 300s)
--   3. Network rules (CARTO tiles + PyPI)
--   4. External Access Integration binding both rules
--   5. FinOps tags on compute pool
--   6. Grants for STREAMLIT_ROLE + viewer roles
--
-- Prereqs: AD_ANALYTICS.OPS schema + STREAMLIT_ROLE already exist
--          (created by cost monitor bootstrap — 01_bootstrap.sql).

use role accountadmin;

-- ---------------------------------------------------------------------------
-- 1. Stage
-- ---------------------------------------------------------------------------

use role streamlit_role;
use schema ad_analytics.ops;

create stage if not exists sales_dashboard_stage
    directory = (enable = true)
    comment = 'Source stage for the Ammunition Depot Sales Dashboard Streamlit app';

-- ---------------------------------------------------------------------------
-- 2. Compute pool
-- ---------------------------------------------------------------------------

use role accountadmin;

create compute pool if not exists sales_dashboard_pool
    min_nodes = 1
    max_nodes = 1
    instance_family = cpu_x64_xs
    auto_resume = true
    auto_suspend_secs = 300
    comment = 'Streamlit container runtime for AD_ANALYTICS.OPS.SALES_DASHBOARD';

grant usage, monitor on compute pool sales_dashboard_pool to role streamlit_role;

-- ---------------------------------------------------------------------------
-- 3. Network rules — CARTO tiles + PyPI
-- ---------------------------------------------------------------------------

create or replace network rule ad_analytics.ops.carto_tiles_rule
    type = host_port
    mode = egress
    value_list = ('basemaps.cartocdn.com')
    comment = 'Egress to CARTO CDN for Scattermapbox dark tiles';

create or replace network rule ad_analytics.ops.sales_dashboard_pypi_rule
    type = host_port
    mode = egress
    value_list = ('pypi.org', 'files.pythonhosted.org')
    comment = 'Egress to PyPI for container runtime package installation';

grant usage on network rule ad_analytics.ops.carto_tiles_rule to role streamlit_role;
grant usage on network rule ad_analytics.ops.sales_dashboard_pypi_rule to role streamlit_role;

-- ---------------------------------------------------------------------------
-- 4. External Access Integration
-- ---------------------------------------------------------------------------

create or replace external access integration sales_dashboard_integration
    allowed_network_rules = (
        ad_analytics.ops.carto_tiles_rule,
        ad_analytics.ops.sales_dashboard_pypi_rule
    )
    enabled = true
    comment = 'Sales dashboard → CARTO tiles + PyPI for container runtime';

grant usage on integration sales_dashboard_integration to role streamlit_role;

-- ---------------------------------------------------------------------------
-- 5. FinOps tags
-- ---------------------------------------------------------------------------

alter compute pool sales_dashboard_pool set tag
    governance.tags.service = 'streamlit',
    governance.tags.client  = 'ammodepot';

-- ---------------------------------------------------------------------------
-- 6. Viewer grants
-- ---------------------------------------------------------------------------

-- Viewer roles get USAGE on schema (already granted by cost monitor bootstrap).
-- Streamlit object USAGE must be granted AFTER first deploy (object must exist).
-- Run post-deploy:
--   GRANT USAGE ON STREAMLIT AD_ANALYTICS.OPS.SALES_DASHBOARD
--     TO ROLE DASHBOARD_VIEWER_ROLE;
--   GRANT USAGE ON STREAMLIT AD_ANALYTICS.OPS.SALES_DASHBOARD
--     TO ROLE POWERBI_READONLY_ROLE;
```

### Pattern 4: CI/CD Workflow

```yaml
# .github/workflows/deploy-streamlit-dashboard.yml
# Cloned from deploy-streamlit-cost-monitor.yml, adapted for sales dashboard.
name: Deploy Streamlit Sales Dashboard

on:
  push:
    branches: [main]
    paths:
      - 'streamlit_app/**'
      - '.github/workflows/deploy-streamlit-dashboard.yml'
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    env:
      SNOWFLAKE_ACCOUNT: iwb48385.us-east-1
      SNOWFLAKE_USER: SVC_DBT
      SNOWFLAKE_ROLE: STREAMLIT_ROLE
      SNOWFLAKE_WAREHOUSE: COMPUTE_WH
      SNOWFLAKE_DATABASE: AD_ANALYTICS
      SNOWFLAKE_SCHEMA: OPS

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

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
          key = d["SNOWFLAKE_PRIVATE_KEY"]
          key_path = pathlib.Path("/tmp/sf_rsa_key.p8")
          key_path.write_text(key)
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

      - name: Install Snowflake CLI
        run: |
          python3 -m pip install --upgrade pip
          python3 -m pip install 'snowflake-cli-labs>=2.7' || \
            python3 -m pip install 'snowflake-cli>=2.7'
          snow --version

      - name: Write Snowflake CLI config
        run: |
          set -euo pipefail
          mkdir -p ~/.snowflake
          cat > ~/.snowflake/config.toml <<EOF
          default_connection_name = "deploy"

          [connections.deploy]
          account = "${SNOWFLAKE_ACCOUNT}"
          user = "${SNOWFLAKE_USER}"
          role = "${SNOWFLAKE_ROLE}"
          warehouse = "${SNOWFLAKE_WAREHOUSE}"
          database = "${SNOWFLAKE_DATABASE}"
          schema = "${SNOWFLAKE_SCHEMA}"
          authenticator = "SNOWFLAKE_JWT"
          private_key_file = "${SNOWFLAKE_PRIVATE_KEY_PATH}"
          EOF
          chmod 600 ~/.snowflake/config.toml

      - name: Deploy Streamlit app
        working-directory: streamlit_app
        env:
          PRIVATE_KEY_PASSPHRASE: ${{ env.SNOWFLAKE_PRIVATE_KEY_PASSPHRASE }}
        run: |
          snow streamlit deploy --replace --connection deploy

      # --replace strips EAI. Re-attach immediately.
      - name: Attach EAI to Streamlit app
        env:
          PRIVATE_KEY_PASSPHRASE: ${{ env.SNOWFLAKE_PRIVATE_KEY_PASSPHRASE }}
        run: |
          snow sql --connection deploy -q "
            alter streamlit ad_analytics.ops.sales_dashboard set
              external_access_integrations = (sales_dashboard_integration)
          "

      - name: Smoke test — describe the Streamlit object
        env:
          PRIVATE_KEY_PASSPHRASE: ${{ env.SNOWFLAKE_PRIVATE_KEY_PASSPHRASE }}
        run: |
          snow sql --connection deploy -q "describe streamlit ad_analytics.ops.sales_dashboard"
```

### Pattern 5: Chart Click Guard Removal (Pages 1 and 2)

**Before** (Page 1, line ~809 / Page 2, line ~723):
```python
    if chart_key and filter_key and not _is_sis:
        event = st.plotly_chart(
            fig, use_container_width=True,
            on_select="rerun", key=chart_key,
        )
        try:
            sel = event.selection if event else None
            if sel and not callable(sel) and hasattr(sel, "points") and sel.points:
                ...
        except (AttributeError, TypeError, IndexError):
            pass
    else:
        st.plotly_chart(fig, use_container_width=True)
```

**After** (remove `and not _is_sis` from condition):
```python
    if chart_key and filter_key:
        event = st.plotly_chart(
            fig, use_container_width=True,
            on_select="rerun", key=chart_key,
        )
        try:
            sel = event.selection if event else None
            if sel and not callable(sel) and hasattr(sel, "points") and sel.points:
                ...
        except (AttributeError, TypeError, IndexError):
            pass
    else:
        st.plotly_chart(fig, use_container_width=True)
```

**Change:** Remove `and not _is_sis` from the condition. The `not callable(sel)` safety check already handles the edge case where `event.selection` returns a callable instead of data.

### Pattern 6: Map Guard Removal (Pages 1 and 2)

**Before** (Page 1, lines ~1308-1345 / Page 2, lines ~1460-1494):
```python
            from utils.db import _is_sis
            if _is_sis:
                sis_map = pd.DataFrame({
                    "latitude": lat_list,
                    "longitude": lon_list,
                    "size": size_list,
                })
                try:
                    st.map(sis_map, size="size")
                except TypeError:
                    st.map(sis_map[["latitude", "longitude"]])
            else:
                fig = go.Figure(go.Scattermapbox(...))
                apply_theme(...)
                fig.update_layout(mapbox=dict(
                    style="carto-darkmatter",
                    center=dict(lat=38, lon=-97),
                    zoom=3,
                ))
                st.plotly_chart(fig, use_container_width=True)
```

**After** (keep only Scattermapbox branch, remove `_is_sis` import and `st.map` fallback):
```python
            fig = go.Figure(go.Scattermapbox(
                lat=lat_list,
                lon=lon_list,
                marker=dict(
                    size=size_list,
                    color="#00d4aa",
                    opacity=0.6,
                ),
                text=hover_texts,
                hoverinfo="text",
            ))
            apply_theme(
                fig, height=350, show_legend=False,
                margin=dict(l=0, r=0, t=0, b=0),
            )
            fig.update_layout(
                mapbox=dict(
                    style="carto-darkmatter",
                    center=dict(lat=38, lon=-97),
                    zoom=3,
                ),
            )
            st.plotly_chart(fig, use_container_width=True)
```

**Change:** Remove the `from utils.db import _is_sis` local import, the `if _is_sis:` branch (entire `st.map` fallback), and the `else:`. Keep only the Scattermapbox code, dedented one level.

**Import cleanup:** After removing all map guards, check if `_is_sis` is still imported at the top of each page. If the only remaining usage is in the chart click guard (which we also removed), remove `_is_sis` from the top-level import line:

```python
# Before:
from utils.db import run_query, _is_sis

# After (if _is_sis no longer used anywhere in the file):
from utils.db import run_query
```

---

## Data Flow

```text
1. Developer pushes to streamlit_app/ on main
   │
   ▼
2. GitHub Actions triggers deploy-streamlit-dashboard.yml
   │
   ├─ Fetches SVC_DBT key from Secrets Manager
   ├─ Installs Snowflake CLI
   ├─ Writes CLI config with STREAMLIT_ROLE
   │
   ▼
3. snow streamlit deploy --replace --connection deploy
   │
   ├─ Uploads artifacts to sales_dashboard_stage
   ├─ Creates/replaces Streamlit object
   ├─ Container runtime pulls requirements.txt → pip install
   │  └─ Requires PyPI egress (sales_dashboard_pypi_rule)
   │
   ▼
4. ALTER STREAMLIT SET EAI (re-attach stripped integration)
   │
   ▼
5. DESCRIBE STREAMLIT (smoke test verifies deploy + EAI)
   │
   ▼
6. User navigates to AD_ANALYTICS.OPS.SALES_DASHBOARD
   │
   ├─ Streamlit loads on sales_dashboard_pool (container runtime)
   ├─ Queries execute on COMPUTE_WH
   ├─ Maps fetch CARTO tiles via carto_tiles_rule
   └─ Chart clicks handled via on_select="rerun"
```

---

## Integration Points

| External System | Integration Type | Authentication |
|-----------------|-----------------|----------------|
| Snowflake GOLD layer | SQL via Snowpark session | Owner role (STREAMLIT_ROLE) |
| CARTO CDN (`basemaps.cartocdn.com`) | HTTPS (map tiles) | None (public CDN) |
| PyPI (`pypi.org`, `files.pythonhosted.org`) | HTTPS (package install) | None (public) |
| GitHub Actions | CI/CD trigger | `SVC_DBT` key-pair via Secrets Manager |
| AWS Secrets Manager | Key retrieval in CI | `svc_iac` IAM user |

---

## Testing Strategy

| Test Type | Scope | Method | Coverage |
|-----------|-------|--------|----------|
| Smoke test (CI) | Deploy succeeds | `DESCRIBE STREAMLIT` in workflow | AT-001 |
| Manual — maps | Scattermapbox renders CARTO tiles in SiS | Navigate Pages 1+2, check map section | AT-002 |
| Manual — chart clicks | `on_select` fires cross-filter in SiS | Click bar chart, verify filter pills | AT-003 |
| Manual — EAI persistence | EAI attached after deploy | `DESCRIBE STREAMLIT` shows integration | AT-004 |
| Manual — local dev | `streamlit run app.py` works unchanged | Navigate all 3 pages locally | AT-005 |
| Manual — Inventory page | No regressions | Navigate Inventory tabs | AT-006 |
| Manual — FinOps tags | Pool appears in cost reports | Query `GOVERNANCE.TAGS` | AT-007 |
| Manual — viewer access | `DASHBOARD_VIEWER_ROLE` can access app | Login as viewer, navigate | AT-008 |
| Manual — CARTO fallback | Map handles missing tiles gracefully | Temporarily remove EAI, load page | AT-009 |

---

## Error Handling

| Error Type | Handling Strategy | Retry? |
|------------|-------------------|--------|
| CARTO tiles blocked (EAI missing) | Scattermapbox renders with empty map area; page doesn't crash. No code change needed — Plotly handles missing tiles gracefully | No |
| `event.selection` returns callable (container runtime bug) | `not callable(sel)` guard already in chart click handler prevents crash | No |
| PyPI egress blocked | Container startup fails with pip install error. CI smoke test catches this. Fix: verify EAI has PyPI rule | No |
| `--replace` strips EAI | CI re-attaches via `ALTER STREAMLIT SET` immediately after deploy | Auto (CI step) |
| Compute pool suspended | `auto_resume = true` starts pool on first request | Auto |

---

## Configuration

| Config Key | Type | Default | Description |
|------------|------|---------|-------------|
| `runtime_name` | string | `SYSTEM$ST_CONTAINER_RUNTIME_PY3_11` | Container runtime identifier |
| `compute_pool` | string | `sales_dashboard_pool` | Dedicated pool for this app |
| `query_warehouse` | string | `compute_wh` | BI warehouse for SQL queries |
| `auto_suspend_secs` | int | `300` | Pool auto-suspend (5 min) |
| `instance_family` | string | `cpu_x64_xs` | Smallest container instance |

---

## Security Considerations

- No secrets needed for this app (unlike cost monitor which uses AWS keys) — only map tile egress and PyPI
- EAI scoped to minimum egress: CARTO CDN + PyPI only
- `STREAMLIT_ROLE` owns the app; viewer roles get USAGE on the Streamlit object only
- `SVC_DBT` key-pair used in CI/CD (same as cost monitor — no new credentials)
- No new IAM users or Snowflake service accounts required

---

## Observability

| Aspect | Implementation |
|--------|----------------|
| Deploy success | GitHub Actions workflow status + smoke test step |
| Runtime errors | Snowflake event table (container runtime logs) |
| Cost attribution | `GOVERNANCE.TAGS.service = 'streamlit'` on compute pool |
| Pool utilization | `SHOW COMPUTE POOLS` + `DESCRIBE COMPUTE POOL sales_dashboard_pool` |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-14 | design-agent | Initial version |

---

## Next Step

**Ready for:** `/build .claude/sdd/features/DESIGN_SIS_CONTAINER_MIGRATION.md`
