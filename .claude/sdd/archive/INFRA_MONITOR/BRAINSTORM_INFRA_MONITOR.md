# BRAINSTORM: Infra Monitor Expansion

> Exploratory session to clarify intent and approach before requirements capture

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | INFRA_MONITOR |
| **Date** | 2026-04-15 |
| **Author** | brainstorm-agent |
| **Status** | Ready for Define |

---

## Initial Idea

**Raw Input:** Expand the Snowflake + AWS Cost Monitor Streamlit app into a broader "Snowflake + AWS Infra Monitor" by adding a dbt Pipeline page (build duration from CloudWatch, build health from logs) and embedding auto-generated dbt documentation (static site) that refreshes on model changes. Rename the app accordingly.

**Context Gathered:**
- Current app is `AD_ANALYTICS.OPS.COST_MONITOR` (4 pages: Snowflake Compute, Snowflake Storage, AWS Infrastructure, Combined)
- ECS entrypoint already publishes `BuildDurationMinutes` to CloudWatch namespace `AmmoDepot/dbt` and logs structured markers (`BUILD_DURATION_SECONDS`, `ICEBERG_REFRESH_SECONDS`, pass/warn/error counts)
- CloudWatch logs at `/ecs/ammodepot-dbt` contain full build output
- Existing alarms: `dbt-build-failure` (matches `[31mERROR`), `dbt-task-missing` (no runs in 30 min)
- Build runs every 10 min via EventBridge; ~6 min steady state with 10-min ceiling as main watchpoint
- AWS boto3 pattern established in `utils/aws_costs.py` (dual-mode creds: SiS secret + local default chain)
- EAI `aws_cost_explorer_integration` allows egress to `ce.us-east-1.amazonaws.com` + PyPI

**Technical Context Observed (for Define):**

| Aspect | Observation | Implication |
|--------|-------------|-------------|
| Likely Location | `streamlit_cost_monitor/` | Extend existing app, add Page 5 |
| New CI Workflow | `.github/workflows/` | New `deploy-dbt-docs.yml` for S3 upload |
| S3 Bucket | New `ammodepot-dbt-docs` bucket | Static website hosting for dbt docs |
| EAI Changes | `aws_cost_explorer_integration` | Add CloudWatch + Logs endpoints |
| Relevant KB Domains | streamlit, cloudwatch, fargate, github | Patterns to consult |

---

## Discovery Questions & Answers

| # | Question | Answer | Impact |
|---|----------|--------|--------|
| 1 | dbt docs detail level: (a) lightweight catalog, (b) full lineage DAG, (c) just build health? | **(b) Full lineage DAG** — interactive DAG with descriptions, test coverage | Need full `dbt docs generate` static site, not custom rendering |
| 2 | Docs freshness mechanism: (a) ECS every build, (b) CI on code changes, (c) hybrid? | **(b) CI on code changes** — user specified "only when there are changes in the model" | New GitHub Actions workflow triggered by `ammodepot/` path changes |
| 3 | Embedding approach: (a) S3 static site + iframe, (b) Snowflake stage + st.html, (c) CloudFront + S3? | **(a) S3 static website + iframe** — preserves full interactive dbt docs experience (DAG, search) | Need S3 bucket with static website hosting; iframe loaded by browser (no EAI needed for docs) |
| 4 | Build metrics scope: (a) just duration chart, (b) duration + build health, (c) full observability? | **(b) Duration + build health** — duration chart with 10-min ceiling line + build health table from log parsing | Need boto3 CloudWatch + Logs clients; parse structured log markers |
| 5 | Rename scope: (a) full rename (Snowflake object + CI + titles), (b) soft rename (display only)? | **(a) Full rename** — `COST_MONITOR` → `INFRA_MONITOR` everywhere. Leave compute pool name as-is | Update Snowflake object, CI workflow, viewer grants, page titles |
| 6 | CI docs generation: (a) manifest-only (no Snowflake creds), (b) full catalog (needs creds)? | **(a) Manifest-only** — `dbt parse` in CI, no Snowflake connection needed | DAG + descriptions + tests available; column types/row counts deferred |

---

## Sample Data Inventory

| Type | Location | Count | Notes |
|------|----------|-------|-------|
| CloudWatch metric | `AmmoDepot/dbt` namespace, `BuildDurationMinutes` | Continuous | Published by `ecs/entrypoint.sh` after every build |
| CloudWatch logs | `/ecs/ammodepot-dbt` log group | Continuous | Structured markers: `BUILD_DURATION_SECONDS`, `ICEBERG_REFRESH_SECONDS`, ANSI pass/warn/error |
| Existing boto3 pattern | `streamlit_cost_monitor/utils/aws_costs.py` | 1 file | Dual-mode creds, cached queries, Cost Explorer client |
| ECS entrypoint | `ecs/entrypoint.sh` | 1 file | Shows all metrics published and log format |
| dbt project | `ammodepot/` | 101 models | Source for `dbt parse` → manifest.json |

**How samples will be used:**
- CloudWatch metric format informs the `get_metric_data` query structure
- Log markers define the parsing regex patterns for build health extraction
- Existing `aws_costs.py` is the template for the new `cloudwatch_metrics.py` module
- `entrypoint.sh` is the source of truth for what data is available

---

## Approaches Explored

### Approach A: S3 Static Docs + CloudWatch Metrics via boto3 (Recommended)

**Description:** Add Page 5 to the existing cost monitor app with three sections: (1) Build Duration line chart from CloudWatch `GetMetricData`, (2) Build Health table from CloudWatch Logs `FilterLogEvents`, (3) dbt Docs iframe from S3-hosted static site. CI generates docs on model changes via `dbt parse`. Full rename to INFRA_MONITOR.

**Pros:**
- Reuses established boto3 pattern (dual-mode creds, cached queries)
- dbt docs iframe preserves full interactive experience (DAG, search, descriptions)
- Manifest-only generation keeps CI simple (no Snowflake creds)
- Single EAI update (add CloudWatch + Logs endpoints to existing integration)
- S3 docs loaded by browser — no EAI needed for the iframe

**Cons:**
- S3 static website hosting makes docs publicly accessible (mitigated by non-guessable bucket name)
- No catalog.json means no column types or row counts in docs (deferred)
- CloudWatch Logs parsing is regex-based on structured markers — fragile if log format changes

**Why Recommended:** Lowest complexity, reuses all existing patterns, delivers the three requested capabilities (duration chart, build health, dbt docs) with minimal new infrastructure.

---

### Approach B: Snowflake-Native (Stage + Tables)

**Description:** Instead of S3 + CloudWatch, store everything in Snowflake: ECS uploads build metrics to a Snowflake table after each run, CI uploads manifest.json to an internal stage, Streamlit reads both via SQL/Snowpark. No external API calls needed on the Streamlit side.

**Pros:**
- Zero external API calls from Streamlit (no EAI changes)
- Build history queryable via SQL
- Docs served from Snowflake stage (no public S3)

**Cons:**
- Requires changing ECS entrypoint to write to Snowflake (additional complexity, latency)
- Docs from stage can't be served as iframe (no static website hosting) — would need custom rendering
- Loses the interactive dbt docs experience (DAG viewer, search)
- More moving parts in ECS (Snowflake writes + CloudWatch writes)

---

### Approach C: CloudWatch Embedded Dashboards

**Description:** Use CloudWatch's embeddable dashboard feature to inject the existing `ammodepot-dbt` dashboard directly into Streamlit via iframe, rather than querying the API.

**Pros:**
- Near-zero development — embed existing dashboard as-is
- Real-time, no caching logic needed

**Cons:**
- CloudWatch embedded dashboards require IAM authentication (signed URLs, complex in SiS)
- No customization of chart appearance (no dark theme match, no ceiling line)
- Doesn't solve the dbt docs or build health table requirements
- Mixes visual styles (CloudWatch light theme inside dark Streamlit app)

---

## Selected Approach

| Attribute | Value |
|-----------|-------|
| **Chosen** | Approach A: S3 Static Docs + CloudWatch Metrics via boto3 |
| **User Confirmation** | 2026-04-15 |
| **Reasoning** | Reuses all existing patterns, delivers full interactive dbt docs, keeps CI simple with manifest-only generation |

---

## Key Decisions Made

| # | Decision | Rationale | Alternative Rejected |
|---|----------|-----------|----------------------|
| 1 | Full lineage DAG via dbt docs static site | User wants interactive DAG + descriptions + test coverage | Lightweight model catalog table |
| 2 | S3 static website + iframe embedding | Preserves full dbt docs JS interactivity (DAG, search); browser loads directly | Snowflake stage (can't serve as website), st.html injection (JS relative paths break) |
| 3 | CI generates on code changes only | Docs reflect model definitions, not build cadence; avoids 10-min churn | ECS generates every build (unnecessary overhead) |
| 4 | Manifest-only (no catalog.json) | Avoids adding Snowflake key-pair management to CI; DAG + descriptions is the 90% use case | Full catalog (requires Snowflake creds in GitHub secrets) |
| 5 | Full rename COST_MONITOR → INFRA_MONITOR | Small internal team, one-time bookmark update; consistent naming | Soft rename (display only, mismatched object name) |
| 6 | Duration chart + build health table | Covers the 10-min ceiling watchpoint + recent build status | Duration only (loses build status context) |
| 7 | Leave compute pool name as `cost_monitor_pool` | Cosmetic, nobody sees it, avoids infra churn | Rename pool (risk of downtime, no user benefit) |

---

## Features Removed (YAGNI)

| Feature Suggested | Reason Removed | Can Add Later? |
|-------------------|----------------|----------------|
| catalog.json (column types, row counts) | Requires Snowflake creds in CI — over-engineers MVP | Yes — add GitHub secret + `dbt docs generate` step |
| CloudFront + signed URLs for docs | Non-guessable bucket name is sufficient for internal team | Yes — if docs content becomes sensitive |
| Alarm status / trend analysis | Build health table + ceiling line cover the need | Yes — add alarm state via `describe_alarms` |
| Compute pool rename | Cosmetic, nobody sees it | Low value |
| Custom domain for docs site | Over-engineering for an internal tool | Maybe — if sharing externally |
| Full observability (trend analysis, anomaly detection) | Build health table is sufficient for current team size | Yes — when pipeline complexity grows |

---

## Incremental Validations

| Section | Presented | User Feedback | Adjusted? |
|---------|-----------|---------------|-----------|
| Architecture diagram (data flows, components, EAI) | Yes | "looks right" | No |
| Scope & YAGNI (in/out, deferred features) | Yes | Confirmed, proceed | No |

---

## Suggested Requirements for /define

Based on this brainstorm session, the following should be captured in the DEFINE phase:

### Problem Statement (Draft)

The Cost Monitor app covers Snowflake + AWS spend but lacks visibility into dbt pipeline health (build duration, pass/fail status) and model documentation — forcing the team to check CloudWatch separately and losing dbt docs discoverability.

### Target Users (Draft)

| User | Pain Point |
|------|------------|
| Victor (data engineer) | Monitors build duration in CloudWatch separately; no single pane of glass for infra + pipeline |
| Analytics team | No self-serve access to dbt model documentation, lineage, or test coverage |

### Success Criteria (Draft)

- [ ] App renamed to INFRA_MONITOR (Snowflake object, CI, titles)
- [ ] Page 5 shows Build Duration chart with 10-min ceiling reference line
- [ ] Page 5 shows Build Health table with recent builds (status, duration, iceberg refresh, pass/warn/error)
- [ ] Page 5 embeds interactive dbt docs via iframe (DAG, search, descriptions)
- [ ] CI workflow generates manifest.json and uploads to S3 on `ammodepot/` changes
- [ ] EAI updated with CloudWatch + Logs endpoints
- [ ] Existing pages 1-4 unchanged and functional
- [ ] Viewer roles retain access to renamed object

### Constraints Identified

- EAI must add `monitoring.us-east-1.amazonaws.com` + `logs.us-east-1.amazonaws.com`
- S3 docs bucket publicly accessible (static website hosting) — mitigate with non-guessable name
- CloudWatch Logs parsing depends on structured markers in `entrypoint.sh` — format changes break parsing
- `dbt parse` requires dbt + project files in CI — need a lightweight Docker step or uv install
- `--replace` deploy will strip EAI — existing CI re-attach pattern applies
- Same AWS credential mechanism as existing Cost Explorer (SiS secret + local default chain)

### Out of Scope (Confirmed)

- catalog.json with column types / row counts (requires Snowflake creds in CI)
- CloudFront / signed URLs for docs (non-guessable bucket name is sufficient)
- Alarm status display or trend analysis
- Compute pool rename
- Custom domain for docs site

---

## Implementation Components (for Design)

### New Files

| File | Purpose |
|------|---------|
| `streamlit_cost_monitor/pages/5_dbt_Pipeline.py` | Page 5: duration chart + health table + docs iframe |
| `streamlit_cost_monitor/utils/cloudwatch_metrics.py` | boto3 CloudWatch + Logs client, cached queries |
| `.github/workflows/deploy-dbt-docs.yml` | CI: dbt parse + upload to S3 |
| `streamlit_cost_monitor/setup/05_add_cloudwatch_egress.sql` | EAI update: add CloudWatch + Logs endpoints |

### Modified Files

| File | Change |
|------|--------|
| `streamlit_cost_monitor/streamlit_app.py` | Rename title + description |
| `streamlit_cost_monitor/app.py` | Rename title (local entrypoint) |
| `streamlit_cost_monitor/snowflake.yml` | Update object name to `INFRA_MONITOR` |
| `streamlit_cost_monitor/utils/config.py` | Add CloudWatch config constants (namespace, metric name, log group, lookback) |
| `.github/workflows/deploy-streamlit-cost-monitor.yml` | Update Snowflake object name, add re-attach for updated EAI |

### Infrastructure

| Resource | Action |
|----------|--------|
| S3 bucket `ammodepot-dbt-docs` | Create with static website hosting enabled |
| EAI `aws_cost_explorer_integration` | Add network rules for CloudWatch + Logs endpoints |
| Snowflake object | DROP old `COST_MONITOR`, deploy as `INFRA_MONITOR` |
| Viewer grants | Re-grant USAGE on new object to `DASHBOARD_VIEWER_ROLE` + `POWERBI_READONLY_ROLE` |
| IAM | `svc_iac` may need CloudWatch read permissions (verify — likely already has via ADBIadmin group) |

---

## Session Summary

| Metric | Value |
|--------|-------|
| Questions Asked | 6 |
| Approaches Explored | 3 |
| Features Removed (YAGNI) | 6 |
| Validations Completed | 2 |

---

## Next Step

**Ready for:** `/define .claude/sdd/features/BRAINSTORM_INFRA_MONITOR.md`
