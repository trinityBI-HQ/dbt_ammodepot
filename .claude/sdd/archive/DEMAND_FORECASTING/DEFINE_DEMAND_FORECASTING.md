# DEFINE: Demand Forecasting with SNOWFLAKE.ML.FORECAST

> Predict units sold by caliber over the next 30 days using Snowflake's native ML.FORECAST, combined with current inventory and vendor lead times to generate stock-out risk alerts and reorder recommendations

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | DEMAND_FORECASTING |
| **Date** | 2026-04-15 |
| **Author** | define-agent |
| **Status** | Ready for Design |
| **Clarity Score** | 15/15 |
| **Source** | [BRAINSTORM_DEMAND_FORECASTING.md](BRAINSTORM_DEMAND_FORECASTING.md) |

---

## Problem Statement

Operations cannot predict future demand to time reorder decisions. The Inventory page (Page 3) shows backward-looking Days of Supply calculated from historical averages, which misses seasonal patterns (hunting season spikes, election-year surges) and trend shifts. When a caliber like 5.56 NATO has 123 units on hand and vendor lead time is 14 days, operations doesn't know if they'll stock out in 2 days or 20 — they need a forward-looking prediction combined with lead time data to know *when* to place the PO.

Revenue projection has the same gap: executives use "last month" as a proxy for next month, with no statistical forecasting.

---

## Target Users

| User | Role | Pain Point |
|------|------|------------|
| Operations team (Seth + warehouse) | Inventory management, PO placement | Can't predict which calibers will stock out and when to place POs. Relies on gut feel + backward-looking averages. Misses seasonal demand changes |
| Executive / ownership | Budget planning, cash flow | No revenue projection for next 30 days. Uses prior month as proxy. Can't plan purchasing budget or staffing |

---

## Goals

| Priority | Goal |
|----------|------|
| **MUST** | FORECAST model trains daily on f_sales, predicting units by caliber for next 30 days |
| **MUST** | Predictions stored in `F_FORECAST` Gold table (caliber, date, predicted_units, lower_bound, upper_bound) |
| **MUST** | Stock-out risk table: F_FORECAST + F_INVENTORYVIEW + F_POS → days-to-stockout, reorder-by date per caliber |
| **MUST** | New Streamlit page (`4_Forecast.py`) in Sales Dashboard with forecast chart + stock-out risk table |
| **MUST** | Snowflake Task runs daily at 4am UTC, completes in < 2 minutes |
| **SHOULD** | Revenue forecast (single-series, daily total) for executive projection |
| **SHOULD** | Sparse caliber fallback: calibers with < 730 days of data roll up to category-level forecast |
| **COULD** | Forecast data available to Cortex Analyst chatbot via semantic view expansion |
| **COULD** | Confidence interval bands (LOWER_BOUND, UPPER_BOUND) displayed in forecast chart |

---

## Success Criteria

Measurable outcomes:

- [ ] **Accuracy**: Backtest MAPE < 20% at caliber level (train through Dec 2025, predict Jan-Mar 2026, compare to actuals)
- [ ] **Coverage**: Forecasts generated for calibers representing 90%+ of total units sold
- [ ] **Freshness**: Predictions refresh daily by 4:30am UTC (30-min SLA from 4am trigger)
- [ ] **Stock-out detection**: Stock-out risk table correctly identifies calibers with < 14 days of predicted supply
- [ ] **Performance**: Streamlit Page 4 loads in < 3 seconds (reads pre-computed F_FORECAST)
- [ ] **Task reliability**: Snowflake Task succeeds on 95%+ of daily runs (monitored via TASK_HISTORY)
- [ ] **Cost**: Total incremental cost < $5/mo (Task compute + F_FORECAST storage)
- [ ] **Revenue forecast**: Single-series daily revenue prediction with MAPE < 15%

---

## Acceptance Tests

| ID | Scenario | Given | When | Then |
|----|----------|-------|------|------|
| AT-001 | Caliber forecast generated | FORECAST model trained on f_sales | Task runs at 4am | F_FORECAST contains 30 rows per caliber (one per future day) with predicted_units, lower_bound, upper_bound |
| AT-002 | Stock-out risk detection | 5.56 NATO has 123 units on hand, predicted demand is 50/day | Page 4 loads | Stock-out risk table shows 5.56 NATO with 2.5 days of supply, "Critical" risk, reorder-by date = today |
| AT-003 | Healthy stock detection | 9mm has 137,981 units on hand, predicted demand is 1,500/day | Page 4 loads | Stock-out risk table shows 9mm with 92 days of supply, "Low" risk |
| AT-004 | Revenue forecast | Single-series model trained on daily revenue | Task runs | F_FORECAST contains 30 rows for "REVENUE" series with predicted_revenue |
| AT-005 | Sparse caliber fallback | A caliber has only 200 days of sales data (< 730 min) | Task runs | Caliber excluded from per-caliber model; falls back to category-level forecast or is flagged as "Insufficient data" |
| AT-006 | Page load performance | F_FORECAST has 3,600 rows (120 calibers x 30 days) | User visits Page 4 | Page renders in < 3 seconds |
| AT-007 | Backtest accuracy | Model trained on data through Dec 2025 | Predictions for Jan-Mar 2026 compared to actuals | MAPE < 20% across calibers with sufficient data |
| AT-008 | Task failure handling | Snowflake Task fails (e.g., warehouse suspended) | Next scheduled run | Task retries automatically; F_FORECAST retains last successful predictions |
| AT-009 | Forecast chart rendering | User visits Page 4 | Selects a caliber | Line chart shows: actual last 30 days + predicted next 30 days + optional confidence bands |
| AT-010 | Reorder-by date calculation | Caliber has 5,000 units, predicted demand 200/day, vendor lead time 14 days | Page 4 loads | Reorder-by = today + (5000/200) - 14 = today + 11 days. Shows "Order by April 26" |

---

## Out of Scope

Explicitly NOT included in Phase 2:

- **SKU-level forecasting** — too many sparse series; start with caliber, drill down in Phase 2b if accuracy is good
- **Automated PO generation** — show recommendations only; let operations decide when to order
- **Email/Slack stock-out alerts** — Phase 3 (anomaly detection) is the better vehicle for alerts
- **Multi-horizon forecasts** — 30 days only; 7d and 90d add complexity without proven value
- **Exogenous variables** (weather, elections, holidays) — FORECAST supports them but adds data ingestion; test baseline first
- **Forecast accuracy monitoring dashboard** — backtest once during validation; permanent monitoring is premature
- **Confidence interval chart visualization** — store LOWER/UPPER_BOUND in F_FORECAST but don't chart in Phase 2
- **Cortex Analyst chatbot integration** — store data in Gold for future semantic view expansion, but don't expand the view in Phase 2

---

## Constraints

| Type | Constraint | Impact |
|------|------------|--------|
| **Data** | FORECAST needs 2+ seasonal cycles (~730 daily rows per series) | Calibers with < 2 years of data need fallback (category-level or exclusion) |
| **API** | FORECAST is a stored procedure (CALL), not a SQL function | Cannot run inside dbt models; must use Snowflake Task or external scheduler |
| **Compute** | 10-min ECS build already at 60% of schedule headroom | FORECAST training MUST be separate from dbt build (Snowflake Task, not ECS) |
| **RBAC** | EXECUTE TASK privilege required | ACCOUNTADMIN grants to TRANSFORMER_ROLE during bootstrap |
| **Schema** | F_FORECAST must be in GOLD schema | Existing RBAC grants cover DASHBOARD_VIEWER_ROLE + POWERBI_READONLY_ROLE |
| **Cost** | Client is cost-conscious (~$34K/yr savings realized so far) | Total < $5/mo — use XSMALL warehouse, auto-suspend, minimal Task frequency |
| **SiS** | Streamlit page in existing Sales Dashboard app | Must follow dark theme, chart patterns, SiS container runtime constraints |

---

## Technical Context

| Aspect | Value | Notes |
|--------|-------|-------|
| **Deployment Location** | `streamlit_app/pages/4_Forecast.py` (Streamlit) + `streamlit_app/setup/03_forecast_setup.sql` (Snowflake objects) | New page in existing Sales Dashboard + bootstrap SQL for Task/procedure/table |
| **KB Domains** | `snowflake` (Cortex ML Functions, FORECAST), `streamlit` (SiS) | KB exists: `concepts/cortex-ml-functions.md` |
| **IaC Impact** | New Snowflake objects: Task, Stored Procedure, View, Table | All created via bootstrap SQL, owned by TRANSFORMER_ROLE |

### Snowflake Objects to Create

| Object | Name | Owner Role | Purpose |
|--------|------|-----------|---------|
| View | `V_DAILY_SALES_BY_CALIBER` | TRANSFORMER_ROLE | Training input: daily units aggregated from f_sales + d_product |
| Stored Procedure | `SP_TRAIN_FORECAST` | TRANSFORMER_ROLE | Trains FORECAST model + writes predictions to F_FORECAST |
| Task | `TASK_DAILY_FORECAST` | TRANSFORMER_ROLE | Runs SP_TRAIN_FORECAST daily at 4am UTC |
| Table | `F_FORECAST` | TRANSFORMER_ROLE | Gold table: predictions (caliber, date, units, bounds) |

### Data Flow

```
f_sales + int_product_analyst
    ↓ (aggregation view)
V_DAILY_SALES_BY_CALIBER (daily units per caliber, 3+ years)
    ↓ (Snowflake Task, daily 4am UTC)
SP_TRAIN_FORECAST
    ↓ (SNOWFLAKE.ML.FORECAST)
F_FORECAST (caliber, date, predicted_units, lower_bound, upper_bound)
    ↓ (Streamlit Page 4 reads)
F_FORECAST + F_INVENTORYVIEW + F_POS
    ↓ (stock-out calculation)
Stock-out risk table + forecast chart
```

---

## Assumptions

| ID | Assumption | If Wrong, Impact | Validated? |
|----|------------|------------------|------------|
| A-001 | f_sales has 730+ daily rows for most calibers (2+ years) | Many calibers would fail training; need aggressive category-level fallback | [ ] Query f_sales to count days per caliber |
| A-002 | SNOWFLAKE.ML.FORECAST trains in < 60s for 120 caliber series | Task would exceed 2-min SLA; may need to split into batches | [ ] Test with actual data during build |
| A-003 | Ammo demand has seasonal patterns FORECAST can detect | Model would be no better than simple moving average | [ ] Backtest validates this |
| A-004 | XSMALL warehouse is sufficient for FORECAST training | Would need SMALL or MEDIUM (~$2-5/mo more) | [ ] Test during build |
| A-005 | TRANSFORMER_ROLE can create Snowflake Tasks | Would need ACCOUNTADMIN grant for EXECUTE TASK | [ ] Test during bootstrap |
| A-006 | F_FORECAST table with 3,600 rows loads fast in Streamlit | Should be trivial but verify with actual Snowpark query | [x] Confirmed — smaller than f_sales |

---

## Deliverables

| # | Deliverable | Type | Location |
|---|-------------|------|----------|
| 1 | Training input view | SQL | `V_DAILY_SALES_BY_CALIBER` in GOLD schema |
| 2 | Stored procedure | SQL | `SP_TRAIN_FORECAST` in GOLD schema |
| 3 | Snowflake Task | SQL | `TASK_DAILY_FORECAST` in GOLD schema |
| 4 | Predictions table | SQL | `F_FORECAST` in GOLD schema |
| 5 | Bootstrap SQL | SQL | `streamlit_app/setup/03_forecast_setup.sql` |
| 6 | Streamlit forecast page | Python | `streamlit_app/pages/4_Forecast.py` |
| 7 | Backtest validation script | Python | `streamlit_app/test_forecast_backtest.py` |

---

## Cost Estimate

| Component | Monthly |
|-----------|---------|
| Snowflake Task (XSMALL, ~30s/day) | ~$1-3 |
| F_FORECAST table storage (3,600 rows) | < $0.01 |
| Streamlit page | $0 incremental (same compute pool) |
| **Total** | **~$1-3/mo** |

---

## Clarity Score Breakdown

| Element | Score (0-3) | Notes |
|---------|-------------|-------|
| Problem | 3 | Specific: backward DoS misses seasons; operations can't time POs |
| Users | 3 | Two personas with concrete pain points (reorder timing, revenue projection) |
| Goals | 3 | MoSCoW prioritized; 5 MUST, 2 SHOULD, 2 COULD |
| Success | 3 | 8 quantified criteria (MAPE <20%, <3s load, <$5/mo, <2min Task) |
| Scope | 3 | 8 YAGNI cuts, 7 deliverables, explicit constraints |
| **Total** | **15/15** | |

---

## Open Questions

None — ready for Design. All questions resolved during brainstorm:
- What to forecast: units by caliber + revenue (Q1)
- Granularity: caliber ~120 series (Q2)
- Architecture: Snowflake Task + Gold table + Streamlit page (Q3)

One assumption to validate early in build:
- A-001: Count of calibers with 730+ days of sales data (determines fallback scope)

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-15 | define-agent | Initial version from BRAINSTORM_DEMAND_FORECASTING.md |

---

## Next Step

**Ready for:** `/design .claude/sdd/features/DEFINE_DEMAND_FORECASTING.md`
