---
paths: ["ammodepot/macros/ml_forecast.sql", "ammodepot/models/gold/**", "ammodepot/snapshots/**", "streamlit_app/pages/**"]
---
# The Cortex features

Everything runs inside Snowflake — the client provides no external LLM or API keys
(`../decisions/0005-cortex-over-external-llm.md`).

| Feature | Built on | Writes | Surfaces in |
|---|---|---|---|
| Demand forecast | `SNOWFLAKE.ML.FORECAST` — `CALIBER_FORECAST` (115 calibers), `REVENUE_FORECAST` | `GOLD.F_FORECAST`, archived to `F_FORECAST_HISTORY` before each retrain | dashboard page 4 |
| Anomaly detection | `SNOWFLAKE.ML.ANOMALY_DETECTION` — revenue, orders, margin | `GOLD.F_ANOMALIES` | alert banner on page 1 |
| Reorder recommendations | dbt model `F_REORDER_RECOMMENDATIONS` | refreshed with every build | page 4 |
| Customer narratives | `SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b')` over `D_CUSTOMER_SEGMENTATION` | — | page 5 |
| Analyst chatbot | Cortex Analyst over a semantic view | — | `../../streamlit_analyst/` |

## How they run

- **`F_FORECAST` and `F_ANOMALIES` belong to a Snowflake Task**, `TASK_DAILY_FORECAST` (weekly,
  Sunday 04:00 UTC), which retrains and predicts. dbt cannot `ref()` them — models read them by name.
- Training is dbt macros in `ammodepot/macros/ml_forecast.sql`, run with
  `dbt run-operation train_all_ml_models --target prod`. Inputs are `int_daily_sales_by_caliber` and
  `int_daily_sales_metrics`. FORECAST over 115 series takes ~31 minutes on an XS warehouse.
- **Anomaly detection needs training and detection windows that do not overlap.**
- **Reorder quantity** = `greatest(0, DEMAND_UPPER_30D - QTY_AVAILABLE - QTY_ON_ORDER)`: the forecast's
  upper bound is the safety buffer. The recommended vendor has the lowest average
  `PRECISE_LEADTIME` in `F_POS` for that caliber.
- **Forecast accuracy** comes from `F_FORECAST_HISTORY` against actual sales — `EVALUATE()` does not
  support multi-series models.
- The narratives use `llama3.1-70b` because `gemini-2-5-flash` returns 400 in this region
  (us-east-1).
- `SNAP_CUSTOMER_SEGMENTATION` (check strategy, `invalidate_hard_deletes`) feeds page 5's
  month-over-month deltas. Its unique key is `customer_email` — `rank_id` shifts between runs.
