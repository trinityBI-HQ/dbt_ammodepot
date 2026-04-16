# BRAINSTORM: Sales & Cost Anomaly Detection

> Exploratory session to clarify intent and approach before requirements capture

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | ANOMALY_DETECTION |
| **Date** | 2026-04-15 |
| **Author** | brainstorm-agent |
| **Status** | Ready for Define |

---

## Initial Idea

**Raw Input:** Phase 3 of the 5-phase AI feature roadmap. Detect sudden drops in daily revenue, unusual margin changes, and unexpected order count shifts using SNOWFLAKE.ML.ANOMALY_DETECTION. Display alerts on the Streamlit Sales Dashboard Page 1 (Today/Yesterday) where operations starts every morning.

**Context Gathered:**
- Phase 1 (Cortex Analyst chatbot) and Phase 2 (demand forecasting) shipped 2026-04-15
- Weekly Snowflake Task already runs FORECAST — anomaly detection adds to the same Task
- Page 1 (Today/Yesterday) has 5 KPI cards: Net Sales, GP, Orders, Shipping Revenue, GP After Variable Cost
- Cost Monitor app already has anomaly detection for Snowflake compute costs (pattern reference)
- Client constraint: no external APIs — ANOMALY_DETECTION runs on warehouse compute

**Technical Context Observed (for Define):**

| Aspect | Observation | Implication |
|--------|-------------|-------------|
| Likely Location | Update `streamlit_app/pages/1_Today_Yesterday.py` (alert banner) | No new page — embed in existing daily dashboard |
| Relevant KB Domains | snowflake (Cortex ML Functions) | KB exists: `concepts/cortex-ml-functions.md` |
| IaC Patterns | Extend existing Snowflake Task + stored procedure from Phase 2 | No new Task — add steps to SP_TRAIN_FORECAST |

---

## Discovery Questions & Answers

| # | Question | Answer | Impact |
|---|----------|--------|--------|
| 1 | What metrics to monitor? | Daily revenue, daily order count, daily gross margin %. Based on PBI KPI cards that operations checks every morning | 3 anomaly models (one per metric), single training view |
| 2 | Where to display? | Alert banner on Page 1 (Today/Yesterday) — where operations starts every day. Collapsible anomaly history | No new page; modify existing page |
| 3 | Architecture direction? | User agreed with full recommendation: add to existing Task, 3 metrics, alert banner, $0 incremental cost | Proceed |

---

## Sample Data Inventory

| Type | Location | Count | Notes |
|------|----------|-------|-------|
| Daily sales metrics | `AD_ANALYTICS.GOLD.F_SALES` | 3+ years daily | Revenue, orders, margin — same source as FORECAST |
| Cost Monitor anomaly pattern | `streamlit_cost_monitor/utils/snowflake_queries.py` | 1 file | Reference for anomaly SQL pattern |
| Page 1 KPI cards | `streamlit_app/pages/1_Today_Yesterday.py` | 1,355 lines | Banner insertion point above KPI cards |
| Existing Task | `streamlit_app/setup/03_forecast_setup.sql` | 134 lines | SP_TRAIN_FORECAST to extend |

---

## Approaches Explored

### Approach A: Extend Existing Task + Alert Banner (Recommended)

**Description:** Add anomaly detection steps to SP_TRAIN_FORECAST, store results in F_ANOMALIES Gold table, render as alert banner on Page 1. Three models: revenue, orders, margin.

**Pros:**
- $0 incremental cost (adds ~30s to existing weekly Task)
- No new Snowflake objects except F_ANOMALIES table and one view
- Alert banner on Page 1 is where operations already looks
- Reuses proven Task + stored procedure pattern

**Cons:**
- Weekly detection means anomalies are flagged 1-7 days late
- Alert banner modifies a 1,355-line file (risk of regression)

**Why Recommended:** Simplest, cheapest, highest-impact placement. Weekly cadence is acceptable — anomalies in revenue/orders are visible in the KPI cards same-day; the model provides statistical confirmation.

---

### Approach B: Separate Task + Dedicated Page

**Description:** New Snowflake Task for anomaly detection, new Streamlit page (5_Anomalies.py).

**Pros:**
- Independent schedule (could run daily)
- No risk to existing Page 1

**Cons:**
- Extra Task = extra cost + management
- Separate page = operations might not check it daily

---

## Selected Approach

| Attribute | Value |
|-----------|-------|
| **Chosen** | Approach A (Extend existing Task + alert banner) |
| **User Confirmation** | 2026-04-15 |
| **Reasoning** | $0 incremental, highest visibility (Page 1), reuses Phase 2 infrastructure |

---

## Key Decisions Made

| # | Decision | Rationale | Alternative Rejected |
|---|----------|-----------|----------------------|
| 1 | 3 aggregate metrics only (revenue, orders, margin) | Per-caliber anomaly detection has too many series; aggregate catches business-level issues | Per-caliber anomaly (too many models) |
| 2 | Alert banner on Page 1, not separate page | Operations starts here every morning; separate page would be ignored | Dedicated anomaly page |
| 3 | Extend SP_TRAIN_FORECAST, not new Task | $0 cost, same schedule, simpler management | Separate daily Task |
| 4 | Weekly retrain, not daily | Model doesn't change that fast; weekly is sufficient for anomaly baseline | Daily retrain (31+ min already) |

---

## Features Removed (YAGNI)

| Feature Suggested | Reason Removed | Can Add Later? |
|-------------------|----------------|----------------|
| Email/Slack alerts | Phase 3 is dashboard-only; notifications add integration complexity | Yes |
| Per-caliber anomaly detection | Too many series; monitor aggregates first | Yes (Phase 3b) |
| Real-time detection (every 10 min) | Daily granularity is sufficient; weekly retrain | Maybe |
| Root cause analysis | Just flag the anomaly; user investigates | Yes (Phase 4 with COMPLETE) |
| Custom thresholds | Use ANOMALY_DETECTION statistical defaults | Yes |
| Anomaly severity scoring | IS_ANOMALY boolean + DISTANCE is enough | Maybe |

---

## Incremental Validations

| Section | Presented | User Feedback | Adjusted? |
|---------|-----------|---------------|-----------|
| Full recommendation (metrics, architecture, display, YAGNI) | Yes | "I agree with this proposal" | No |

---

## Suggested Requirements for /define

### Problem Statement (Draft)

Operations discovers sales anomalies reactively — someone asks "why was yesterday slow?" after the fact. Daily KPI cards on Page 1 show today vs yesterday, but can't distinguish normal variance from statistical anomalies. A revenue drop from $120K to $95K could be a typical Monday dip or a checkout outage — the dashboard can't tell.

### Target Users (Draft)

| User | Pain Point |
|------|------------|
| Operations team | Discovers revenue drops, margin compression, order volume changes hours or days late |
| Executive | No proactive alert when business metrics deviate from expected patterns |

### Success Criteria (Draft)

- [ ] ANOMALY_DETECTION models trained weekly for revenue, orders, margin
- [ ] F_ANOMALIES table stores flagged anomalies with expected vs actual + distance
- [ ] Alert banner on Page 1 shows anomalies from last 7 days
- [ ] Known historical anomalies (holidays, website outages) correctly flagged
- [ ] $0 incremental cost (runs in existing Task)
- [ ] Page 1 load time not impacted (< 0.5s overhead from F_ANOMALIES query)

### Out of Scope (Confirmed)

- Email/Slack notifications
- Per-caliber anomaly detection
- Real-time detection
- Root cause analysis
- Custom thresholds

### Deliverables (Draft)

| # | File | Action |
|---|------|--------|
| 1 | `streamlit_app/setup/03_forecast_setup.sql` | Modify — add V_DAILY_SALES_METRICS, F_ANOMALIES, anomaly steps in SP_TRAIN_FORECAST |
| 2 | `streamlit_app/pages/1_Today_Yesterday.py` | Modify — add anomaly alert banner above KPI cards |
| 3 | `streamlit_app/test_anomaly_validation.py` | Create — validation script |

---

## Session Summary

| Metric | Value |
|--------|-------|
| Questions Asked | 3 (metrics, display, architecture) |
| Approaches Explored | 2 (extend Task vs separate Task) |
| Features Removed (YAGNI) | 6 |
| Validations Completed | 1 (full recommendation confirmed) |
| Duration | ~10 min |

---

## Next Step

**Ready for:** `/define .claude/sdd/features/BRAINSTORM_ANOMALY_DETECTION.md`
