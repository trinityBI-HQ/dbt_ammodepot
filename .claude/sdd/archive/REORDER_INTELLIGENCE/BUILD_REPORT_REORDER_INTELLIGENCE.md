# BUILD REPORT: Inventory Reorder Intelligence

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | REORDER_INTELLIGENCE |
| **Date** | 2026-04-16 |
| **DESIGN** | `.claude/sdd/features/DESIGN_REORDER_INTELLIGENCE.md` |
| **Status** | Code Complete — Needs Live Validation |

---

## Files Created / Modified

| # | File | Action | Lines | Status |
|---|------|--------|-------|--------|
| 1 | `ammodepot/models/gold/f_reorder_recommendations.sql` | Created | 95 | dbt refs verified (5/5) |
| 2 | `ammodepot/models/gold/f_reorder_recommendations.yml` | Created | 60 | YAML valid |
| 3 | `streamlit_app/pages/4_Forecast.py` | Modified | 333→476 (+143) | Syntax OK |

---

## Implementation Summary

### dbt Gold Model (`f_reorder_recommendations`)

5-CTE model following project CTE pattern:

| CTE | Purpose |
|-----|---------|
| `forecast_upper` | SUM(UPPER_BOUND) + AVG(predicted_units) by caliber, next 30 days from F_FORECAST |
| `inventory_by_caliber` | SUM(QTY_AVAILABLE, QTY_ON_ORDER) aggregated to caliber via INT_PRODUCT_ANALYST |
| `vendor_agg` | AVG(PRECISE_LEADTIME, UNIT_COST) by caliber×vendor from F_POS |
| `best_vendor` | QUALIFY ROW_NUMBER — picks lowest-lead-time vendor per caliber |
| `reorder_calc` | Computes REORDER_QTY, DAYS_OF_SUPPLY, REORDER_BY, URGENCY |
| `final` | UPPER_CASE aliases + D_VENDOR join + ESTIMATED_ORDER_COST + REFRESHED_AT |

**Auto-config from `dbt_project.yml`:** `+materialized: table`, `+transient: true`, `+query_tag: 'dbt:gold'` — no per-model config block needed.

**dbt Tests (5):** CALIBER unique+not_null, REORDER_QTY non-negative, QTY_AVAILABLE non-negative, QTY_ON_ORDER non-negative, URGENCY accepted_values (4 values), ESTIMATED_ORDER_COST non-negative, REFRESHED_AT not_null.

### Streamlit Page 4 Modifications

Added to `4_Forecast.py`:
- `LLM_MODEL_REORDER = "gemini-2-5-flash"` + `LLM_CACHE_TTL_REORDER = 600`
- `load_reorder_recommendations()` — cached 10 min, `try/except` returns empty DataFrame on error
- `generate_reorder_summary()` — CORTEX.COMPLETE, cached 10 min, returns None on error
- `st.tabs()` extended: 3 tabs → 4 tabs (added "Reorder Recommendations")
- `tab_reorder` block: LLM banner, 3 KPI metrics, urgency filter selectbox, `dark_dataframe()` table

### FinOps Tagging

No new Snowflake resources created. Existing tagging applies:
- dbt model queries auto-tagged `dbt:gold` via `dbt_project.yml`
- CORTEX.COMPLETE calls billed as Cortex LLM credits (not warehouse credits); tracked via `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CONSUMPTION` — no warehouse tag possible or needed

---

## Verification

| Check | Result |
|-------|--------|
| Python syntax (`ast.parse`) | Pass |
| dbt `ref()` calls (5/5) | Pass: f_forecast, f_inventoryview, int_product_analyst, f_pos, d_vendor |
| Tab wiring (4 tabs) | Pass: tab_risk, tab_caliber, tab_revenue, tab_reorder |
| New functions present | Pass: load_reorder_recommendations, generate_reorder_summary |
| Line count | 476 (estimate was 450-480) |
| No modifications to tabs 1-3 | Pass |

---

## Live Validation Required

| Test | AT-ID | How to Validate |
|------|-------|-----------------|
| dbt build passes | AT-001, AT-009 | `dbt build --select f_reorder_recommendations` |
| REORDER_QTY ≥ 0 | AT-002 | `SELECT MIN(REORDER_QTY) FROM F_REORDER_RECOMMENDATIONS` |
| URGENCY classification | AT-003 | Spot-check Critical rows vs Page 4 Stock-Out Risk |
| New tab renders | AT-004 | Open Page 4 in Snowsight, click "Reorder Recommendations" |
| Existing tabs unaffected | AT-005 | Verify Stock-Out Risk, Caliber Forecast, Revenue Forecast tabs work |
| LLM fallback | AT-006 | Temporarily set `LLM_MODEL_REORDER = "nonexistent"`, reload |
| Vendor populated | AT-007 | `SELECT COUNT(*) FROM F_REORDER_RECOMMENDATIONS WHERE RECOMMENDED_VENDOR IS NOT NULL` |
| SiS compatibility | AT-010 | Deploy + open in Snowsight container runtime |

---

## Known Limitations

1. **Demand side refreshes weekly** — UPPER_BOUND from F_FORECAST only updates when TASK_DAILY_FORECAST runs (Sunday 4am UTC). Inventory side updates every 10 min. Recommendations reflect latest inventory against last weekly forecast.
2. **Single vendor per caliber** — best vendor = lowest avg lead time. Cost not considered. Multi-vendor comparison deferred.
3. **No automated tests** — consistent with Pages 1-4.

---

## Cost Impact

| Resource | Change | Monthly Cost |
|----------|--------|-------------|
| `ETL_WH` dbt build | +1 Gold table (~10-20s/run) | Negligible (<$0.01/mo) |
| CORTEX.COMPLETE tokens | New (~600 calls/mo) | ~$0.15/mo |
| **Net incremental** | | **~$0.15/mo** |

---

## Next Steps

1. Push to main → CI builds new ECR image → ECS runs `dbt build` (picks up new model)
2. `dbt build --select f_reorder_recommendations` — confirm 0 errors, tests pass
3. Push `streamlit_app/` → CI deploys to SiS → validate Page 4 "Reorder Recommendations" tab
4. Ship → `/ship REORDER_INTELLIGENCE`
