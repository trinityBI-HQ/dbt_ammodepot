# BUILD REPORT: SiS Container Runtime Migration

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | SIS_CONTAINER_MIGRATION |
| **Date** | 2026-04-14 |
| **DESIGN** | `.claude/sdd/features/DESIGN_SIS_CONTAINER_MIGRATION.md` |
| **Status** | Complete |

---

## Execution Summary

| # | Task | Action | Status | Notes |
|---|------|--------|--------|-------|
| 1 | `streamlit_app/snowflake.yml` | Create | Done | Container runtime config, sales_dashboard_pool, compute_wh |
| 2 | `streamlit_app/requirements.txt` | Create | Done | streamlit>=1.55, plotly>=5.22, pandas>=2.0, snowpark>=1.20 |
| 3 | `streamlit_app/setup/01_bootstrap.sql` | Create | Done | Pool, EAI, network rules (CARTO + PyPI), FinOps tags, grants |
| 4 | `.github/workflows/deploy-streamlit-dashboard.yml` | Create | Done | Deploy + EAI re-attach + smoke test (cloned from cost monitor) |
| 5 | `pages/1_Today_Yesterday.py` | Modify | Done | Removed `and not _is_sis` from chart click guard (line 809) |
| 6 | `pages/1_Today_Yesterday.py` | Modify | Done | Removed `_is_sis` map guard (lines 1308-1345) — Scattermapbox only |
| 7 | `pages/2_Sales_Overview.py` | Modify | Done | Removed `and not _is_sis` from chart click guard (line 723) |
| 8 | `pages/2_Sales_Overview.py` | Modify | Done | Removed `_is_sis` map guard (lines 1460-1494) — Scattermapbox only |
| 9 | `pages/1_Today_Yesterday.py` | Modify | Done | Removed unused `_is_sis` import from line 14 |
| 10 | `pages/2_Sales_Overview.py` | Modify | Done | Removed unused `_is_sis` import from line 14 |
| 11 | `streamlit_app/environment.yml` | Delete | Done | Replaced by requirements.txt |

---

## Verification

| Check | Result |
|-------|--------|
| `_is_sis` in page files | Zero references — only remains in `utils/db.py` (intentional) |
| New files exist | All 4 confirmed: snowflake.yml, requirements.txt, setup/01_bootstrap.sql, workflow |
| environment.yml deleted | Confirmed — file no longer exists |
| No stray imports | `from utils.db import run_query` (no `_is_sis`) on both pages |

---

## Files Changed

### Created (4)

| File | Lines |
|------|-------|
| `streamlit_app/snowflake.yml` | 25 |
| `streamlit_app/requirements.txt` | 7 |
| `streamlit_app/setup/01_bootstrap.sql` | 97 |
| `.github/workflows/deploy-streamlit-dashboard.yml` | 100 |

### Modified (2)

| File | Changes |
|------|---------|
| `streamlit_app/pages/1_Today_Yesterday.py` | -27 lines (removed _is_sis guard + st.map fallback + import), +0 lines |
| `streamlit_app/pages/2_Sales_Overview.py` | -24 lines (removed _is_sis guard + st.map fallback + import), +0 lines |

### Deleted (1)

| File | Reason |
|------|--------|
| `streamlit_app/environment.yml` | Replaced by requirements.txt (container runtime uses pip) |

---

## Pre-Deploy Checklist

Before merging, the following ACCOUNTADMIN steps must be run once:

1. **Run bootstrap SQL**: `streamlit_app/setup/01_bootstrap.sql` as ACCOUNTADMIN
2. **First deploy**: Push to main or run `snow streamlit deploy --replace` manually
3. **Grant viewer access** (after first deploy creates the object):
   ```sql
   use role accountadmin;
   grant usage on streamlit ad_analytics.ops.sales_dashboard
     to role dashboard_viewer_role;
   grant usage on streamlit ad_analytics.ops.sales_dashboard
     to role powerbi_readonly_role;
   ```
4. **Validate** (manual acceptance tests from DEFINE):
   - AT-002: Map renders CARTO dark tiles in SiS
   - AT-003: Chart click cross-filtering works in SiS
   - AT-004: DESCRIBE STREAMLIT shows EAI attached
   - AT-005: Local dev (`streamlit run app.py`) still works

---

## Assumptions to Validate Post-Deploy

| ID | Assumption | How to Validate |
|----|------------|-----------------|
| A-002 | `basemaps.cartocdn.com` is the only CARTO domain needed | Load map in SiS — if tiles fail, check browser network tab for blocked domains |
| A-006 | `event.selection` returns data object in container runtime | Click a chart bar in SiS — if cross-filter doesn't activate, check console logs |

---

## Next Step

**Ready for:** `/ship .claude/sdd/features/DEFINE_SIS_CONTAINER_MIGRATION.md` (after manual validation)
