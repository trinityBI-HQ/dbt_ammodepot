# BRAINSTORM: Demand Forecasting with SNOWFLAKE.ML.FORECAST

> Exploratory session to clarify intent and approach before requirements capture

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | DEMAND_FORECASTING |
| **Date** | 2026-04-15 |
| **Author** | brainstorm-agent |
| **Status** | Ready for Define |

---

## Initial Idea

**Raw Input:** Phase 2 of the 5-phase AI feature roadmap. Add demand forecasting using Snowflake's native `SNOWFLAKE.ML.FORECAST` function to predict units sold by caliber over the next 30 days. Combine with current inventory and vendor lead times to generate stock-out risk alerts and reorder recommendations.

**Context Gathered:**
- Phase 1 (Cortex Analyst chatbot) shipped 2026-04-15 — proven SiS deployment, CI/CD, semantic view patterns
- Inventory page (Page 3) already has Days of Supply, Low Stock, Overstock views — but uses backward-looking averages
- f_sales has 3+ years of daily order-line data (~120 caliber series)
- f_inventoryview has current stock snapshot per SKU
- f_pos has vendor lead times (3-tier hierarchy: vendor-product > vendor > product)
- Client constraint: no external APIs — SNOWFLAKE.ML.FORECAST runs on warehouse compute
- Primary users: Operations team (Seth + warehouse) for reorder decisions; Executive for revenue projection

**Technical Context Observed (for Define):**

| Aspect | Observation | Implication |
|--------|-------------|-------------|
| Likely Location | `streamlit_app/pages/4_Forecast.py` (new page in existing Sales Dashboard) | Reuses existing compute pool, CI/CD, dark theme, db.py utils |
| Relevant KB Domains | snowflake (Cortex ML Functions), streamlit (SiS container runtime) | KB entry exists: `.claude/kb/.../concepts/cortex-ml-functions.md` |
| IaC Patterns | Snowflake Task (scheduled daily), Gold table for predictions | New Snowflake objects: Task, stored procedure, F_FORECAST table |

---

## Discovery Questions & Answers

| # | Question | Answer | Impact |
|---|----------|--------|--------|
| 1 | What to forecast and who consumes it? | Units sold by caliber (operations reorder decisions) + daily revenue (executive projection). Based on PBI Inventory page usage — Days of Supply is the #1 metric operations checks daily | Forecast must output units by caliber per day, joinable to f_inventoryview and f_pos |
| 2 | How granular? | By caliber (~120 series). PBI Inventory and Sales Overview both slice by caliber. SKU-level too sparse, category too coarse | SERIES_COLNAME = caliber in FORECAST model |
| 3 | Overall direction? | User agreed with full recommendation: caliber-level units, 30-day horizon, daily training, new Streamlit page in Sales Dashboard, stock-out risk table as key output | Proceed to BRAINSTORM document |

---

## Sample Data Inventory

| Type | Location | Count | Notes |
|------|----------|-------|-------|
| Historical sales | `AD_ANALYTICS.GOLD.F_SALES` | 3+ years daily | CREATED_AT, QTY_ORDERED, joinable to D_PRODUCT for caliber |
| Current inventory | `AD_ANALYTICS.GOLD.F_INVENTORYVIEW` | ~2,000 SKUs | QTY_AVAILABLE, QTY_ON_ORDER per part_number |
| Vendor lead times | `AD_ANALYTICS.GOLD.F_POS` | ~10,000 receipts | PRECISE_LEADTIME (days), 3-tier hierarchy |
| Product attributes | `AD_ANALYTICS.GOLD.INT_PRODUCT_ANALYST` | ~2,000 products | CALIBER column (UPPERCASE, Cortex-compatible) |
| Streamlit patterns | `streamlit_app/pages/3_Inventory.py` | 1,272 lines | Days of Supply calc, Low Stock table, chart patterns |
| Forecast KB | `.claude/kb/.../concepts/cortex-ml-functions.md` | 111 lines | FORECAST syntax, requirements, output format |

**How samples will be used:**
- f_sales daily aggregation by caliber → FORECAST training input view
- f_inventoryview + f_pos → stock-out risk calculation after prediction
- Page 3 Inventory patterns → reuse DoS calculation, dark theme, chart patterns
- KB FORECAST syntax → stored procedure template

---

## Approaches Explored

### Approach A: Snowflake Task + Gold Table + Streamlit Page (Recommended)

**Description:** Daily Snowflake Task trains FORECAST model on a pre-aggregated view (daily units by caliber from f_sales), stores 30-day predictions in a new Gold table `F_FORECAST`. A new Streamlit page (`4_Forecast.py`) in the Sales Dashboard reads F_FORECAST + F_INVENTORYVIEW + F_POS to render forecast charts and stock-out risk table.

**Pros:**
- Predictions are pre-computed — Streamlit page loads instantly (no model training on page visit)
- F_FORECAST table is queryable by the Cortex Analyst chatbot via semantic view expansion
- Daily training is sufficient for 30-day forecasts (ammo demand doesn't change hourly)
- Snowflake Task is ~$1-3/mo (one XSMALL run, ~30s)
- Reuses existing Streamlit infrastructure (compute pool, CI/CD, dark theme)

**Cons:**
- New Snowflake objects to manage (Task, stored procedure, training view)
- Predictions are up to 24h stale (acceptable for 30-day horizon)
- FORECAST model needs monitoring — if accuracy degrades, no automatic alert

**Why Recommended:** Separation of training (batch) from serving (Streamlit) is the standard ML pattern. Pre-computed predictions keep the dashboard fast. The Snowflake Task is simpler than adding model training to the ECS Fargate job.

---

### Approach B: On-Demand Training in Streamlit

**Description:** When a user visits the Forecast page, train the model on the fly and display predictions.

**Pros:**
- No Snowflake Task or scheduled job to manage
- Predictions always fresh

**Cons:**
- FORECAST training takes 30-60s per model — unacceptable page load time
- Multiple concurrent users would each trigger training
- No persistent predictions for the chatbot to query
- Wastes compute (retrains on every page visit)

---

### Approach C: dbt Model with FORECAST Macro

**Description:** Create a dbt model that calls FORECAST via a Snowflake stored procedure in a pre-hook or post-hook.

**Pros:**
- Predictions rebuild with every dbt run (every 10 min)

**Cons:**
- FORECAST is a stored procedure (CALL), not a SQL function — can't be used in a SELECT
- Would add 30-60s to every dbt build (currently ~6 min, 60% of 10-min schedule)
- Mixing ML training with ETL is an anti-pattern (different failure modes, different SLAs)

---

## Selected Approach

| Attribute | Value |
|-----------|-------|
| **Chosen** | Approach A (Snowflake Task + Gold Table + Streamlit Page) |
| **User Confirmation** | 2026-04-15 |
| **Reasoning** | Standard ML pattern (batch train, serve from table). Keeps dbt build fast. Pre-computed predictions serve both Streamlit and chatbot. Snowflake Task is simple and cheap. |

---

## Key Decisions Made

| # | Decision | Rationale | Alternative Rejected |
|---|----------|-----------|----------------------|
| 1 | Forecast units by caliber, not SKU | ~120 caliber series are statistically robust; ~2,000 SKUs have many sparse sellers (1-2/month) that break FORECAST | SKU-level forecasting (too sparse) |
| 2 | 30-day forecast horizon | Matches Inventory page's DoS lookback; gives 2x buffer over median vendor lead time (~12 days) | 7 days (too short for reorder), 90 days (accuracy degrades) |
| 3 | Daily training via Snowflake Task | Ammo demand doesn't change hourly; daily is sufficient for 30-day predictions | Every 10 min via dbt (wastes compute, blocks builds), on-demand (slow UX) |
| 4 | New page in Sales Dashboard, not chatbot | Operations already goes to Page 3 (Inventory) for stock decisions; Page 4 is the natural next tab. Visual forecast charts need Plotly | Separate app (unnecessary), chatbot-only (no charts) |
| 5 | Also forecast daily revenue (single-series) | Trivial marginal cost (one extra model); executive dashboard value for budget projection | Revenue-only (doesn't drive operational decisions) |
| 6 | Store predictions in F_FORECAST Gold table | Queryable by Streamlit + chatbot; testable by dbt; persistent | In-memory only (lost on restart, no chatbot access) |

---

## Features Removed (YAGNI)

| Feature Suggested | Reason Removed | Can Add Later? |
|-------------------|----------------|----------------|
| SKU-level forecasting | Too many sparse series; start with caliber, drill down later if accuracy is good | Yes (Phase 2b) |
| Automated PO generation | Too risky — show recommendations, let operations decide | Yes (Phase 4+) |
| Email/Slack stock-out alerts | Phase 3 (anomaly detection) is the better vehicle for alerts | Yes (Phase 3) |
| Forecast accuracy dashboard | Backtest once during validation; permanent monitoring is premature | Maybe |
| Multi-horizon forecasts (7d, 30d, 90d) | Start with 30d only; multiple horizons add complexity without proven value | Yes |
| Exogenous variables (weather, elections, holidays) | FORECAST supports them but adds data ingestion complexity; test baseline first | Maybe |
| Confidence interval visualization | Include LOWER_BOUND/UPPER_BOUND in F_FORECAST but don't chart them in Phase 2; keep UI simple | Yes |

---

## Incremental Validations

| Section | Presented | User Feedback | Adjusted? |
|---------|-----------|---------------|-----------|
| What to forecast + who consumes (3 options) | Yes | "What do you recommend based on PBI?" — asked for recommendation | Yes — presented full recommendation |
| Complete architecture + YAGNI + scope | Yes | "I agree with your recommendation" | No |

---

## Suggested Requirements for /define

### Problem Statement (Draft)

Operations cannot predict future demand to time reorder decisions. The Inventory page shows backward-looking Days of Supply (historical average), which misses seasonal patterns (hunting season, election cycles) and trend shifts. When a caliber like 5.56 NATO has 123 units on hand and vendor lead time is 14 days, operations doesn't know if they'll stock out in 2 days or 20 — they need a forward-looking prediction.

### Target Users (Draft)

| User | Pain Point |
|------|------------|
| Operations team (Seth + warehouse) | Can't predict which calibers will stock out and when to place POs. Currently relies on gut feel + backward-looking averages |
| Executive / ownership | No revenue projection for next 30 days. Budget planning uses "last month" as proxy |

### Success Criteria (Draft)

- [ ] FORECAST model trains daily on 3+ years of f_sales data, predicting 30 days forward
- [ ] Predictions stored in F_FORECAST table with caliber, date, predicted_units, lower/upper bounds
- [ ] Stock-out risk table: combines F_FORECAST + F_INVENTORYVIEW + F_POS to show days-to-stockout per caliber
- [ ] Backtest MAPE < 20% at caliber level (train on data through Dec 2025, predict Jan-Mar 2026)
- [ ] Revenue forecast (single-series) available for executive dashboard
- [ ] Streamlit Page 4 loads in < 3 seconds (reads pre-computed predictions)
- [ ] Snowflake Task runs daily at 4am UTC, completes in < 2 minutes
- [ ] Total cost < $5/mo incremental

### Constraints Identified

- SNOWFLAKE.ML.FORECAST requires minimum 2 seasonal cycles (~730 daily rows per series)
- Sparse calibers with < 730 days of sales data may fail training — need fallback (category-level forecast)
- FORECAST is a stored procedure (CALL), not SQL — can't run inside dbt models
- Snowflake Task requires ACCOUNTADMIN to create (or EXECUTE TASK privilege)
- F_FORECAST table must be in GOLD schema for existing RBAC grants to cover viewer roles
- 10-min ECS build schedule cannot absorb FORECAST training time (must be separate)

### Out of Scope (Confirmed)

- SKU-level forecasting (too sparse, Phase 2b)
- Automated PO generation (show recommendations only)
- Email/Slack alerts (Phase 3, anomaly detection)
- Multi-horizon forecasts (30d only)
- Exogenous variables (baseline model first)
- Forecast accuracy monitoring dashboard

### Deliverables (Draft)

| # | Deliverable | Type |
|---|-------------|------|
| 1 | Daily aggregation view: `V_DAILY_SALES_BY_CALIBER` | SQL view |
| 2 | Stored procedure: `SP_TRAIN_FORECAST` | SQL stored proc |
| 3 | Snowflake Task: `TASK_DAILY_FORECAST` | SQL task |
| 4 | Gold table: `F_FORECAST` | Table (dbt-external or Task-managed) |
| 5 | Streamlit page: `4_Forecast.py` | Python |
| 6 | Bootstrap SQL: setup/03_forecast_setup.sql | SQL |
| 7 | Backtest validation script | Python |

---

## Session Summary

| Metric | Value |
|--------|-------|
| Questions Asked | 3 (what to forecast, granularity, direction confirmation) |
| Approaches Explored | 3 (Task + table, on-demand, dbt macro) |
| Features Removed (YAGNI) | 7 |
| Validations Completed | 2 |
| Duration | ~15 min |

---

## Next Step

**Ready for:** `/define .claude/sdd/features/BRAINSTORM_DEMAND_FORECASTING.md`
