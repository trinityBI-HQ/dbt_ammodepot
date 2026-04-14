# DEFINE: SiS Container Runtime Migration

> Migrate `streamlit_app/` from warehouse runtime (Streamlit 1.26) to container runtime (1.55+), enabling full feature parity with local development and clean FinOps attribution.

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | SIS_CONTAINER_MIGRATION |
| **Date** | 2026-04-14 |
| **Author** | define-agent |
| **Status** | Ready for Design |
| **Clarity Score** | 15/15 |
| **Brainstorm** | `.claude/sdd/features/BRAINSTORM_SIS_CONTAINER_MIGRATION.md` |

---

## Problem Statement

The `streamlit_app/` BI dashboard runs on SiS warehouse runtime (Streamlit 1.26.0), which locks the app to an outdated Streamlit version, forces degraded map visualizations (`st.map()` instead of Plotly Scattermapbox with CARTO tiles), disables interactive chart click-filtering in SiS, and provides no dedicated compute pool for FinOps cost attribution. The container runtime (GA since 2026-03-09) eliminates all of these limitations, and is already proven in this repo by `streamlit_cost_monitor/`.

---

## Target Users

| User | Role | Pain Point |
|------|------|------------|
| BI dashboard viewers | SSO users via `DASHBOARD_VIEWER_ROLE`, `POWERBI_READONLY_ROLE` | Degraded maps (no CARTO dark tiles), no interactive chart click-filtering in SiS — inferior experience to local dev |
| Dashboard developers | trinityBI engineering team | Must maintain `_is_sis` conditional guards across 2 pages (~4 guard locations), cannot use Streamlit 1.55+ features |
| FinOps team | Cost attribution stakeholders | No dedicated compute pool or tagged resources — dashboard workload is invisible in cost reporting |

---

## Goals

| Priority | Goal |
|----------|------|
| **MUST** | Deploy `streamlit_app/` on container runtime (`SYSTEM$ST_CONTAINER_RUNTIME_PY3_11`) with Streamlit 1.55+ |
| **MUST** | Remove all `_is_sis` rendering guards — enable chart click cross-filtering and Plotly Scattermapbox maps in SiS |
| **MUST** | Create dedicated `sales_dashboard_pool` (CPU_X64_XS, 1 node, auto-suspend 300s) with FinOps tags |
| **MUST** | Create dedicated `sales_dashboard_integration` EAI with CARTO + PyPI egress rules |
| **MUST** | Add GitHub Actions CI/CD workflow that deploys on push and re-attaches EAI post-deploy |
| **SHOULD** | Tag compute pool with `GOVERNANCE.TAGS.service = 'streamlit'` and `GOVERNANCE.TAGS.client = 'ammodepot'` |
| **SHOULD** | Grant `DASHBOARD_VIEWER_ROLE` and `POWERBI_READONLY_ROLE` USAGE on the new Streamlit object |
| **COULD** | Delete `environment.yml` after confirming `requirements.txt` is the sole dependency source |

---

## Success Criteria

- [ ] App runs on container runtime — `DESCRIBE STREAMLIT AD_ANALYTICS.OPS.SALES_DASHBOARD` shows `SYSTEM$ST_CONTAINER_RUNTIME_PY3_11`
- [ ] All 3 dashboard pages load without errors in SiS (Today/Yesterday, Sales Overview, Inventory)
- [ ] Plotly Scattermapbox with CARTO dark tiles renders in SiS on Pages 1 and 2 (replacing `st.map()` fallback)
- [ ] Chart click cross-filtering (`on_select="rerun"`) works in SiS on Pages 1 and 2
- [ ] Zero `_is_sis` rendering guards remain in `pages/1_Today_Yesterday.py` and `pages/2_Sales_Overview.py` (the `_is_sis` flag in `utils/db.py` for session handling remains)
- [ ] `sales_dashboard_pool` exists with `instance_family = CPU_X64_XS`, `auto_suspend_secs = 300`
- [ ] `sales_dashboard_integration` EAI exists with network rules for `basemaps.cartocdn.com` + `pypi.org` + `files.pythonhosted.org`
- [ ] GitHub Actions workflow triggers on push to `streamlit_app/` and successfully deploys
- [ ] CI/CD re-attaches EAI after `--replace` deploy (verified by `DESCRIBE STREAMLIT` showing EAI)
- [ ] Local dev mode (`app.py` with `.env` credentials) continues to work unchanged
- [ ] Incremental cost is ~$5/mo (compute pool only, no new warehouse)

---

## Acceptance Tests

| ID | Scenario | Given | When | Then |
|----|----------|-------|------|------|
| AT-001 | Container runtime deploy | Bootstrap SQL executed, `snowflake.yml` configured | `snow streamlit deploy --replace` runs | App is accessible at `AD_ANALYTICS.OPS.SALES_DASHBOARD` with container runtime |
| AT-002 | Map rendering in SiS | App running on container runtime with EAI attached | Navigate to Today/Yesterday page, scroll to map section | Plotly Scattermapbox renders with CARTO dark tiles (not `st.map()`) |
| AT-003 | Chart click filtering in SiS | App running on container runtime | Click a bar in any chart on Page 1 or 2 | Cross-filter activates, filter pills appear, other charts dim non-selected bars |
| AT-004 | EAI re-attach after deploy | CI/CD runs `snow streamlit deploy --replace` | Deploy completes and post-deploy step runs | `DESCRIBE STREAMLIT` shows `sales_dashboard_integration` in `external_access_integrations` |
| AT-005 | Local dev unchanged | `.env` sourced, `streamlit run app.py` | Navigate all 3 pages | All pages render identically to pre-migration behavior |
| AT-006 | Inventory page (no guards) | App running on container runtime | Navigate to Inventory page | Page loads correctly — no `_is_sis` guards existed here, so no behavioral change |
| AT-007 | FinOps visibility | Compute pool tagged with `service` and `client` | Query `GOVERNANCE.TAGS` attribution | `sales_dashboard_pool` appears in FinOps cost reports with `service=streamlit`, `client=ammodepot` |
| AT-008 | Viewer access | User with `DASHBOARD_VIEWER_ROLE` logs in | Navigates to `AD_ANALYTICS.OPS.SALES_DASHBOARD` | App loads with read-only data access |
| AT-009 | CARTO egress blocked without EAI | EAI not attached (simulated by omitting re-attach step) | App attempts to load map tiles | Map fails gracefully (Plotly shows empty map area, page doesn't crash) |

---

## Out of Scope

- No new dashboard pages or features — migration only
- No Snowpark DataFrame refactor of `utils/db.py` — SQL-based `run_query()` is unchanged
- No auth/role changes beyond granting USAGE on the new Streamlit object
- No multi-node pool or auto-scaling — single node is sufficient
- No warehouse changes — continues using `COMPUTE_WH`
- No changes to `pages/3_Inventory.py` (no `_is_sis` guards exist)
- No changes to `utils/chart_theme.py`, `utils/zip3_coords.py`, or `utils/__init__.py`
- No changes to `streamlit_app.py` or `app.py` entrypoints

---

## Constraints

| Type | Constraint | Impact |
|------|------------|--------|
| Technical | `snow streamlit deploy --replace` strips EAI on every deploy | CI/CD must include a post-deploy `ALTER STREAMLIT SET` step (proven pattern from cost monitor) |
| Technical | CARTO tile domains (`basemaps.cartocdn.com`) require egress via EAI | Dedicated network rule required; maps won't render without EAI attached |
| Technical | Container runtime uses `requirements.txt` (pip), not `environment.yml` (conda) | Must create `requirements.txt` and can remove `environment.yml` |
| Technical | PyPI egress required for container runtime package installation | Network rule for `pypi.org` + `files.pythonhosted.org` must be in EAI |
| Technical | `_is_sis` flag in `utils/db.py` must remain for session/connection dual-mode | Only rendering guards are removed; the session detection pattern is unchanged |
| Access | ACCOUNTADMIN required for one-time setup (compute pool, EAI, network rules) | Must be run manually before first deploy |
| Access | `STREAMLIT_ROLE` owns the app; `SVC_DBT` authenticates in CI | `STREAMLIT_ROLE` must be granted to `SVC_DBT` (already done for cost monitor) |
| Cost | ~$5/mo incremental for `sales_dashboard_pool` | Within budget — same cost as cost monitor pool |

---

## Technical Context

| Aspect | Value | Notes |
|--------|-------|-------|
| **Deployment Location** | `streamlit_app/` (existing) + `streamlit_app/setup/` (new) | Modify existing app in-place, add infra artifacts |
| **KB Domains** | streamlit, snowflake | SiS container runtime patterns, FinOps tag governance |
| **IaC Impact** | New resources: compute pool, EAI, network rules, stage | SQL-based provisioning (matches cost monitor pattern, no Terraform) |

**Why This Matters:**

- **Location** -- Existing app modified in-place; no new directories except `setup/` for bootstrap SQL
- **KB Domains** -- Consult `.claude/kb/automation/streamlit/` for SiS patterns, `.claude/kb/data-engineering/data-platforms/snowflake/` for Snowflake provisioning
- **IaC Impact** -- SQL bootstrap scripts (idempotent `CREATE IF NOT EXISTS`), consistent with cost monitor pattern

---

## Assumptions

| ID | Assumption | If Wrong, Impact | Validated? |
|----|------------|------------------|------------|
| A-001 | Streamlit 1.55+ `on_select="rerun"` works correctly in container runtime | Chart click filtering would need to remain guarded or use alternative event handling | [x] Validated by Streamlit 1.55 release notes |
| A-002 | CARTO tile CDN (`basemaps.cartocdn.com`) is the only domain needed for Scattermapbox | Maps would fail to render; additional domains would need to be added to network rule | [ ] Verify during testing — may need additional CDN domains |
| A-003 | `STREAMLIT_ROLE` already granted to `SVC_DBT` (done during cost monitor setup) | Would need a grant in bootstrap SQL | [x] Validated — bootstrap SQL from cost monitor includes this grant |
| A-004 | `AD_ANALYTICS.OPS` schema already exists (created by cost monitor bootstrap) | Would need to be created; already handled by `CREATE IF NOT EXISTS` | [x] Validated — cost monitor is deployed there |
| A-005 | Single compute pool node (CPU_X64_XS) handles expected concurrent user load | Would need to increase `max_nodes` or upgrade instance family | [x] Validated — current usage is light (internal BI team) |
| A-006 | Container runtime `event.selection` returns a data object (not a callable) unlike warehouse runtime | Would need to keep the `_is_sis` guard for chart clicks | [ ] Verify during testing — this was the specific bug in warehouse runtime |

---

## File Manifest (for Design phase)

### Files to Create

| # | File | Purpose | Template |
|---|------|---------|----------|
| 1 | `streamlit_app/snowflake.yml` | Container runtime deployment config (v2 definition) | `streamlit_cost_monitor/snowflake.yml` |
| 2 | `streamlit_app/requirements.txt` | Pip dependencies for container runtime | `streamlit_cost_monitor/requirements.txt` |
| 3 | `streamlit_app/setup/01_bootstrap.sql` | ACCOUNTADMIN: compute pool, EAI, network rules, stage, grants, FinOps tags | `streamlit_cost_monitor/setup/01_bootstrap.sql` |
| 4 | `.github/workflows/deploy-streamlit-dashboard.yml` | CI/CD: deploy on push, re-attach EAI | `.github/workflows/deploy-streamlit-cost-monitor.yml` |

### Files to Modify

| # | File | Change | Lines Affected |
|---|------|--------|----------------|
| 5 | `streamlit_app/pages/1_Today_Yesterday.py` | Remove `_is_sis` guard on chart clicks (~line 809) | ~5 lines |
| 6 | `streamlit_app/pages/1_Today_Yesterday.py` | Remove `_is_sis` guard on maps (~lines 1308-1320) — use Scattermapbox unconditionally | ~15 lines |
| 7 | `streamlit_app/pages/2_Sales_Overview.py` | Remove `_is_sis` guard on chart clicks (~line 723) | ~5 lines |
| 8 | `streamlit_app/pages/2_Sales_Overview.py` | Remove `_is_sis` guard on maps (~lines 1460-1470) — use Scattermapbox unconditionally | ~15 lines |

### Files to Delete

| # | File | Reason |
|---|------|--------|
| 9 | `streamlit_app/environment.yml` | Replaced by `requirements.txt` (container runtime uses pip) |

### Files NOT Touched

| File | Reason |
|------|--------|
| `streamlit_app/app.py` | Local dev entrypoint — unchanged |
| `streamlit_app/streamlit_app.py` | SiS entrypoint — unchanged |
| `streamlit_app/utils/db.py` | `_is_sis` flag stays for session/connection dual-mode |
| `streamlit_app/utils/chart_theme.py` | No SiS-specific code |
| `streamlit_app/utils/zip3_coords.py` | No SiS-specific code |
| `streamlit_app/utils/__init__.py` | Empty init |
| `streamlit_app/pages/3_Inventory.py` | No `_is_sis` guards to remove |

---

## Clarity Score Breakdown

| Element | Score (0-3) | Notes |
|---------|-------------|-------|
| Problem | 3 | Specific runtime limitation (1.26 vs 1.55+), quantified disabled features (maps + chart clicks), clear impact on 3 user types |
| Users | 3 | Three personas identified with distinct pain points (viewers, developers, FinOps) |
| Goals | 3 | Prioritized MUST/SHOULD/COULD, each tied to a concrete deliverable with measurable outcome |
| Success | 3 | 11 testable criteria, all binary pass/fail, includes both functional and operational checks |
| Scope | 3 | Explicit out-of-scope list from YAGNI (5 items removed during brainstorm), 8 untouched files listed |
| **Total** | **15/15** | |

---

## Open Questions

None -- ready for Design. Two assumptions (A-002: CARTO domains, A-006: `event.selection` behavior) will be validated during testing, not design.

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-14 | define-agent | Initial version from BRAINSTORM_SIS_CONTAINER_MIGRATION.md |

---

## Next Step

**Ready for:** `/design .claude/sdd/features/DEFINE_SIS_CONTAINER_MIGRATION.md`
