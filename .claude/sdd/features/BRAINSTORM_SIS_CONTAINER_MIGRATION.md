# BRAINSTORM: SiS Container Runtime Migration

> Exploratory session to clarify intent and approach before requirements capture

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | SIS_CONTAINER_MIGRATION |
| **Date** | 2026-04-14 |
| **Author** | brainstorm-agent |
| **Status** | Ready for Define |

---

## Initial Idea

**Raw Input:** Migrate `streamlit_app/` from SiS "Run on warehouse" (Streamlit 1.26.0) to "Run on container" runtime (Streamlit 1.55+). Remove SiS workarounds for maps and chart interactivity. Create a dedicated compute pool and EAI with FinOps tags.

**Context Gathered:**
- `streamlit_app/` is ~4,849 lines across 9 Python files (3 dashboard pages + utils)
- Currently deployed with `environment.yml` (warehouse runtime), locked to Streamlit 1.26.0
- Two major SiS workarounds exist: chart click selection disabled via `_is_sis` guards, maps degraded to `st.map()` fallback
- `streamlit_cost_monitor/` already runs on container runtime with `snowflake.yml`, `requirements.txt`, dedicated compute pool, and GitHub Actions CI/CD -- proven template
- Container runtime GA since 2026-03-09, provides Streamlit 1.55+, full PyPI access, and network egress via EAI

**Technical Context Observed (for Define):**

| Aspect | Observation | Implication |
|--------|-------------|-------------|
| Likely Location | `streamlit_app/` (existing) + `streamlit_app/setup/` (new) | Modify existing app in-place, add deployment artifacts |
| Relevant KB Domains | streamlit, snowflake | SiS container patterns, FinOps tagging |
| IaC Patterns | `streamlit_cost_monitor/setup/*.sql` (bootstrap pattern) | Reuse same SQL-based provisioning approach |

---

## Discovery Questions & Answers

| # | Question | Answer | Impact |
|---|----------|--------|--------|
| 1 | What Snowflake schema/database should this app live in? | `AD_ANALYTICS.OPS.SALES_DASHBOARD` | Consistent with cost monitor under OPS schema |
| 2 | Should we reuse `cost_monitor_pool` or create a dedicated pool? | Dedicated `sales_dashboard_pool` (CPU_X64_XS, 1 node, auto-suspend 300s) | Clean FinOps attribution, isolated workload, ~$5/mo |
| 3 | Which SiS workarounds should we remove? | Both -- enable chart click selection AND upgrade maps to Plotly Scattermapbox | Full feature parity between local and SiS |
| 4 | How should we handle CARTO tile network egress? | New dedicated EAI `sales_dashboard_integration` (CARTO + PyPI) | Clean per-app EAI, proper FinOps scope |
| 5 | What reference material to use? | `streamlit_cost_monitor/` as the sole template | Proven pattern, built 5 days ago, same repo |
| 6 | What query warehouse? | `COMPUTE_WH` | Same BI warehouse used by Power BI and cost monitor |

---

## Sample Data Inventory

| Type | Location | Count | Notes |
|------|----------|-------|-------|
| Reference code (container runtime) | `streamlit_cost_monitor/` | 1 app | Working template: snowflake.yml, requirements.txt, setup SQL, CI/CD workflow |
| Reference code (warehouse runtime) | `streamlit_app/` | 1 app | Current app to migrate -- environment.yml, _is_sis guards |
| CI/CD workflow | `.github/workflows/deploy-streamlit-cost-monitor.yml` | 1 | Template for `--replace` + EAI re-attach pattern |
| Setup SQL | `streamlit_cost_monitor/setup/` | 4 files | Bootstrap, secrets, post-deploy, PyPI fix |

**How samples will be used:**

- `snowflake.yml` from cost monitor as template for sales dashboard deployment config
- `setup/01_bootstrap.sql` as template for compute pool + EAI + stage provisioning
- CI/CD workflow as template for GitHub Actions deploy pipeline
- Existing `_is_sis` guard locations as checklist of code to modify

---

## Approaches Explored

### Approach A: In-Place Migration with Feature Parity ⭐ Recommended

**Description:** Migrate `streamlit_app/` to container runtime by adding `snowflake.yml` + `requirements.txt`, replacing `environment.yml`, removing all `_is_sis` rendering guards, creating dedicated infrastructure (pool, EAI), and adding CI/CD.

**Pros:**
- Minimal code changes -- only 4 guard locations in 2 files need modification
- Proven pattern from cost monitor app (5 days old, working in production)
- Full feature parity -- users get the same experience in SiS as local dev
- CARTO dark map tiles replace the degraded `st.map()` fallback
- Interactive chart cross-filtering enabled in SiS (Streamlit 1.55+ supports `on_select`)
- Clean FinOps attribution with dedicated pool + EAI
- CI/CD automates future deploys with the EAI re-attach workaround

**Cons:**
- Requires ACCOUNTADMIN one-time setup (compute pool, EAI, network rules)
- CARTO tile egress adds a network dependency (mitigated by EAI scope)
- ~$5/mo incremental cost for compute pool

**Why Recommended:** Lowest risk, highest reward. The container runtime pattern is already proven in this repo. The migration is surgical -- add deployment config, remove guards, provision infrastructure.

---

### Approach B: Phased Migration (Runtime First, Features Later)

**Description:** Migrate to container runtime but keep all `_is_sis` guards in place. Validate stability first, then remove guards in a follow-up PR.

**Pros:**
- Lower risk per step -- isolates runtime change from feature changes
- Easier to diagnose issues (is it the runtime or the feature?)

**Cons:**
- Two PRs and two deploy cycles for what is fundamentally one change
- Guards are simple conditionals -- removing them is low-risk
- Delays the value delivery (maps + chart clicks) that motivated the migration
- Requires maintaining the guards temporarily, adding cognitive overhead

---

### Approach C: Full Rewrite with Snowpark DataFrames

**Description:** In addition to the runtime migration, refactor `utils/db.py` to use Snowpark DataFrames natively instead of SQL strings, and modernize all data handling.

**Pros:**
- More "Snowflake-native" architecture
- Could improve performance for large result sets

**Cons:**
- Massive scope increase (~4,800 lines of SQL-based query handling to refactor)
- High risk -- touches every query in every page
- `run_query()` works fine and is well-tested
- YAGNI -- no performance issues with current SQL approach

---

## Selected Approach

| Attribute | Value |
|-----------|-------|
| **Chosen** | Approach A: In-Place Migration with Feature Parity |
| **User Confirmation** | 2026-04-14 |
| **Reasoning** | Proven pattern, surgical changes, full feature parity in one PR |

---

## Key Decisions Made

| # | Decision | Rationale | Alternative Rejected |
|---|----------|-----------|----------------------|
| 1 | Dedicated compute pool (`sales_dashboard_pool`) | Clean FinOps isolation, independent scaling | Shared `cost_monitor_pool` (contention risk, muddied attribution) |
| 2 | Dedicated EAI (`sales_dashboard_integration`) | Per-app network scope, FinOps best practice | Broadening existing `aws_cost_explorer_integration` (scope creep) |
| 3 | `AD_ANALYTICS.OPS.SALES_DASHBOARD` | Consistent naming under OPS schema | Different schema (inconsistent with cost monitor) |
| 4 | `COMPUTE_WH` for queries | BI warehouse, same as Power BI | `ETL_WH` (wrong workload class), new warehouse (overkill) |
| 5 | Remove all `_is_sis` rendering guards | Streamlit 1.55+ supports all guarded features | Keep guards (delays value, adds maintenance burden) |
| 6 | Use `requirements.txt` over `environment.yml` | Container runtime uses pip, not conda | Keep `environment.yml` (incompatible with container runtime) |

---

## Features Removed (YAGNI)

| Feature Suggested | Reason Removed | Can Add Later? |
|-------------------|----------------|----------------|
| Snowpark DataFrame refactor of `utils/db.py` | SQL-based `run_query()` works fine, massive scope increase for no clear benefit | Yes |
| Multi-node compute pool | Current usage doesn't warrant scaling beyond 1 node | Yes |
| New dashboard pages | Out of scope -- migration only, no feature additions | Yes |
| Auth/role changes | Existing `STREAMLIT_ROLE` + `DASHBOARD_VIEWER_ROLE` grants are sufficient | Yes |
| Warehouse auto-scaling | Overkill for current user base | Yes |

---

## Incremental Validations

| Section | Presented | User Feedback | Adjusted? |
|---------|-----------|---------------|-----------|
| Migration scope & change table | Presented full before/after comparison | Approved -- "looks right" | No |
| Infrastructure decisions (pool, EAI, warehouse, schema) | Asked one decision at a time (6 questions) | Confirmed all recommendations | No |

---

## Suggested Requirements for /define

Based on this brainstorm session, the following should be captured in the DEFINE phase:

### Problem Statement (Draft)

The `streamlit_app/` BI dashboard runs on SiS warehouse runtime (Streamlit 1.26.0), which forces degraded map visualizations, disabled chart interactivity, and prevents use of modern Streamlit features -- migrating to container runtime eliminates these limitations and achieves full feature parity with local development.

### Target Users (Draft)

| User | Pain Point |
|------|------------|
| BI dashboard viewers (SSO) | Degraded maps (no CARTO tiles), no interactive chart click-filtering in SiS |
| Dashboard developers | Must maintain `_is_sis` conditional guards across 2 pages, can't use Streamlit 1.55+ features |
| FinOps team | No dedicated compute pool or tagged resources for the BI dashboard app |

### Success Criteria (Draft)

- [ ] App deploys and runs on container runtime (`SYSTEM$ST_CONTAINER_RUNTIME_PY3_11`)
- [ ] Plotly Scattermapbox with CARTO dark tiles renders in SiS (replaces `st.map()` fallback)
- [ ] Chart click cross-filtering works in SiS (`on_select="rerun"` enabled)
- [ ] All `_is_sis` rendering guards removed from Pages 1 and 2
- [ ] Dedicated `sales_dashboard_pool` (CPU_X64_XS, 1 node, auto-suspend 300s) provisioned and tagged
- [ ] Dedicated `sales_dashboard_integration` EAI with CARTO + PyPI egress rules
- [ ] GitHub Actions CI/CD workflow deploys on push to `streamlit_app/`
- [ ] CI/CD re-attaches EAI after `--replace` deploy (proven pattern from cost monitor)
- [ ] All 3 dashboard pages (Today/Yesterday, Sales Overview, Inventory) function correctly
- [ ] Local dev mode (`app.py`) continues to work unchanged
- [ ] `DASHBOARD_VIEWER_ROLE` and `POWERBI_READONLY_ROLE` granted USAGE on new Streamlit object

### Constraints Identified

- ACCOUNTADMIN required for one-time setup (compute pool, EAI, network rules)
- `snow streamlit deploy --replace` strips EAI on every deploy -- CI must re-attach
- CARTO tile domains must be added to EAI network rules (`basemaps.cartocdn.com`)
- PyPI egress required in EAI for pip installs during container startup
- `_is_sis` flag in `utils/db.py` must remain for session/connection dual-mode (only rendering guards are removed)
- `environment.yml` replaced by `requirements.txt` -- cannot use both

### Out of Scope (Confirmed)

- No new dashboard pages or features
- No Snowpark DataFrame refactor of `utils/db.py`
- No auth/role changes beyond granting USAGE on new Streamlit object
- No multi-node pool or auto-scaling
- No warehouse changes (continues using `COMPUTE_WH`)
- No changes to `pages/3_Inventory.py` (no `_is_sis` guards to remove)
- No changes to `utils/chart_theme.py` or `utils/zip3_coords.py`

---

## Deliverables Summary

### Files to Create

| File | Purpose |
|------|---------|
| `streamlit_app/snowflake.yml` | Container runtime deployment config (v2 definition) |
| `streamlit_app/requirements.txt` | Pip dependencies: streamlit>=1.55, plotly>=5.22, pandas>=2.0, snowflake-snowpark-python>=1.20 |
| `streamlit_app/setup/01_bootstrap.sql` | ACCOUNTADMIN: compute pool, EAI, network rules, stage, grants |
| `.github/workflows/deploy-streamlit-dashboard.yml` | CI/CD: deploy on push to `streamlit_app/`, re-attach EAI post-deploy |

### Files to Modify

| File | Change |
|------|--------|
| `streamlit_app/pages/1_Today_Yesterday.py` | Remove `_is_sis` guards on chart clicks (line ~809) and maps (lines ~1308-1320) |
| `streamlit_app/pages/2_Sales_Overview.py` | Remove `_is_sis` guards on chart clicks (line ~723) and maps (lines ~1460-1470) |

### Files to Delete

| File | Reason |
|------|--------|
| `streamlit_app/environment.yml` | Replaced by `requirements.txt` (container runtime uses pip, not conda) |

### Files NOT Touched

| File | Reason |
|------|--------|
| `streamlit_app/app.py` | Local dev entrypoint -- unchanged |
| `streamlit_app/streamlit_app.py` | SiS entrypoint -- unchanged |
| `streamlit_app/utils/db.py` | `_is_sis` flag stays for session/connection dual-mode |
| `streamlit_app/utils/chart_theme.py` | No SiS-specific code |
| `streamlit_app/utils/zip3_coords.py` | No SiS-specific code |
| `streamlit_app/pages/3_Inventory.py` | No `_is_sis` guards |

---

## Session Summary

| Metric | Value |
|--------|-------|
| Questions Asked | 6 |
| Approaches Explored | 3 |
| Features Removed (YAGNI) | 5 |
| Validations Completed | 2 |
| Incremental Cost | ~$5/mo (compute pool) |

---

## Next Step

**Ready for:** `/define .claude/sdd/features/BRAINSTORM_SIS_CONTAINER_MIGRATION.md`
