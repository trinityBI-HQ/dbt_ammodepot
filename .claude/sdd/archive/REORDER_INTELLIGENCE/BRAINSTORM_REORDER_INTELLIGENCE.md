# BRAINSTORM: Inventory Reorder Intelligence

> Exploratory session to clarify intent and approach before requirements capture

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | REORDER_INTELLIGENCE |
| **Date** | 2026-04-16 |
| **Author** | brainstorm-agent |
| **Status** | Ready for Define |
| **AI Roadmap** | Phase 5 (follows Churn Narratives) |

---

## Initial Idea

**Raw Input:** Phase 5: Inventory Reorder Intelligence

**Context Gathered:**
- Page 4 (Forecast) already has stock-out risk detection: REORDER_BY dates, DAYS_OF_SUPPLY, risk levels (Critical/Warning/OK/Overstock)
- Gap identified: Page 4 tells *when* to reorder, not *how much* or *from whom*
- `F_FORECAST` has UPPER_BOUND confidence interval — usable as built-in safety buffer
- `F_POS` has vendor-specific lead times (3-tier cascade: vendor×part → vendor → part)
- `F_INVENTORYVIEW` has QTY_ON_HAND and QTY_ON_ORDER per part/caliber
- Pattern established: F_FORECAST and F_ANOMALIES are Gold tables managed by Snowflake Tasks
- Phase 5 is the first *prescriptive* phase — all prior phases were observational

**Technical Context Observed (for Define):**

| Aspect | Observation | Implication |
|--------|-------------|-------------|
| Likely Location | `ammodepot/models/gold/f_reorder_recommendations.sql` + Page 4 new tab | New dbt Gold model + Streamlit tab |
| Data Models | F_FORECAST, F_INVENTORYVIEW, F_POS, D_VENDOR | All inputs exist — no Silver changes needed |
| Existing Pattern | F_FORECAST + F_ANOMALIES are Gold tables, refreshed by weekly Task | f_reorder_recommendations follows same pattern |
| LLM | `gemini-2-5-flash` via CORTEX.COMPLETE | Same model + caching pattern as Phase 4 (Page 5) |
| Compute | `sales_dashboard_pool` (shared) + `ETL_WH` (dbt) | No incremental infra cost |

---

## Discovery Questions & Answers

| # | Question | Answer | Impact |
|---|----------|--------|--------|
| 1 | What does purchasing team do with Page 4 risk table? | Agent recommendation: reorder qty is the missing piece | Core feature is quantity + vendor recommendation |
| 2 | Safety stock formula vs. simple N-day cover? | Agent recommendation: N-day cover using UPPER_BOUND | UPPER_BOUND from F_FORECAST acts as built-in safety buffer — simpler and ML-backed |
| 3 | Where to surface recommendations? | Page 4 — new tab alongside existing tabs | Enhances existing page, no new Streamlit file needed |
| 4 | CORTEX.COMPLETE narrative? | Structured data + one LLM summary banner | Same pattern as Page 5 executive summary |
| 5 | Sample data available? | None | Build from F_FORECAST, F_INVENTORYVIEW, F_POS |

---

## Sample Data Inventory

| Type | Location | Count | Notes |
|------|----------|-------|-------|
| Forecast (UPPER_BOUND) | `AD_ANALYTICS.GOLD.F_FORECAST` | 1 table | 115 calibers × 30 days, UPPER_BOUND = conservative demand estimate |
| Current stock | `AD_ANALYTICS.GOLD.F_INVENTORYVIEW` | 1 table | QTY_ON_HAND, QTY_ON_ORDER, PART_NUMBER grain |
| Lead times + costs | `AD_ANALYTICS.GOLD.F_POS` | 1 table | PRECISE_LEADTIME (3-tier cascade), UNIT_COST, VENDOR_ID |
| Vendor names | `AD_ANALYTICS.GOLD.D_VENDOR` | 1 table | VENDOR_ID → vendor name lookup |
| Product→caliber map | `AD_ANALYTICS.GOLD.INT_PRODUCT_ANALYST` | 1 view | PART_NUMBER → CALIBER mapping |
| Related code | `streamlit_app/pages/4_Forecast.py` | 1 file | `load_stockout_risk()` query pattern to build on |

**How existing data informs the model:**
- `F_FORECAST.UPPER_BOUND` sum over 30 days = conservative demand estimate (built-in safety buffer)
- `F_POS.PRECISE_LEADTIME` already uses 3-tier cascade fallback (vendor×part → vendor → part) — reuse directly
- `INT_PRODUCT_ANALYST` bridges PART_NUMBER (inventory grain) to CALIBER (forecast grain)

---

## Approaches Explored

### Approach A: New dbt Gold Table + Dashboard Tab ⭐ Recommended

**Description:** Pre-compute `f_reorder_recommendations` as a Gold model joining F_FORECAST, F_INVENTORYVIEW, F_POS, D_VENDOR. New "Reorder Recommendations" tab in Page 4 reads from it. CORTEX.COMPLETE banner summarizes top urgent actions.

**Pros:**
- Pre-computed — fast dashboard load, no heavy SQL on page render
- Queryable via Cortex Analyst ("what should we order this week?")
- dbt-tested with generic tests (non-negative REORDER_QTY, valid URGENCY values)
- Consistent with F_FORECAST + F_ANOMALIES pattern
- Single source of truth for purchasing decisions across all consumers

**Cons:**
- Requires new dbt model + ECS deploy (~10 min after push to main)
- Refreshes weekly with TASK_DAILY_FORECAST (not real-time inventory)

---

### Approach B: Dashboard-Computed Only

**Description:** All logic in the Page 4 SQL query (like `load_stockout_risk()`). No new dbt model.

**Pros:**
- No dbt changes, no ECS deploy
- Reflects real-time inventory (10-min cache)

**Cons:**
- Not queryable via Cortex Analyst
- Not dbt-tested
- Complex SQL in dashboard code instead of Gold layer
- Duplicates business logic that belongs in dbt

---

## Selected Approach

| Attribute | Value |
|-----------|-------|
| **Chosen** | Approach A — New dbt Gold Table + Dashboard Tab |
| **User Confirmation** | 2026-04-16 |
| **Reasoning** | Pre-computed, dbt-tested, queryable via Cortex Analyst, consistent with existing Gold table pattern |

---

## Key Decisions Made

| # | Decision | Rationale | Alternative Rejected |
|---|----------|-----------|----------------------|
| 1 | UPPER_BOUND as safety buffer | F_FORECAST UPPER_BOUND = ML-backed conservative estimate; replaces traditional safety stock formula. Simpler and more accurate. | Z × σ × √lead_time safety stock formula (complex, requires σ calculation) |
| 2 | Reorder qty formula: `GREATEST(0, UPPER_BOUND_30D - QTY_ON_HAND - QTY_ON_ORDER)` | Floor at 0 (never negative), accounts for in-transit stock | Simple UPPER_BOUND_30D without netting on-order stock |
| 3 | Best vendor = lowest avg lead time from F_POS | Lead time is the primary operational risk; cost secondary for MVP | Cost-optimized vendor selection (deferred to fast-follow) |
| 4 | Caliber grain (not SKU grain) | Purchasing decisions are made at caliber level, not individual SKU | Per-SKU recommendations (too granular for MVP) |
| 5 | New tab in Page 4, not new page | Keeps forecast/inventory intelligence co-located | New Page 6 (unnecessary fragmentation) |
| 6 | Weekly refresh, same Task as F_FORECAST | No new infra; forecast data is the bottleneck anyway | Separate daily Task (over-engineering) |

---

## Features Removed (YAGNI)

| Feature Suggested | Reason Removed | Can Add Later? |
|-------------------|----------------|----------------|
| Multi-vendor comparison per caliber | One best vendor sufficient for purchasing decision | Yes — show top 3 vendors with lead time + cost |
| Per-SKU recommendations | Caliber grain matches actual purchasing workflow | Yes |
| Cost optimization across vendors | Unit cost in F_POS but vendor comparison adds complexity | Yes — fast-follow |
| Reorder approval workflow | No email/workflow infra exists | Yes |
| Historical recommendation tracking | Interesting but not needed for MVP | Yes |
| Overstock action recommendations | Flag overstock (already in Page 4), don't prescribe action yet | Yes |

---

## Incremental Validations

| Section | Presented | User Feedback | Adjusted? |
|---------|-----------|---------------|-----------|
| Scope summary (location, formula, vendor, refresh, LLM) | Yes | Confirmed, proceed | No |
| YAGNI removals + final scope | Yes | Confirmed, proceed | No |

---

## Suggested Requirements for /define

### Problem Statement (Draft)
The purchasing team can see *when* calibers need reordering (Page 4 stock-out risk) but must manually estimate *how much* to order and *from whom*. There is no system-generated reorder quantity or vendor recommendation, leading to guesswork on purchasing decisions.

### Target Users (Draft)
| User | Pain Point |
|------|------------|
| Purchasing/ops team | Must manually estimate reorder qty from Page 4 risk table — no system recommendation |
| Management | No visibility into estimated total purchasing cost needed this week |

### Success Criteria (Draft)
- [ ] `f_reorder_recommendations` Gold table populated with REORDER_QTY, URGENCY, RECOMMENDED_VENDOR, ESTIMATED_ORDER_COST per caliber
- [ ] New "Reorder Recommendations" tab appears in Page 4 alongside existing tabs
- [ ] CORTEX.COMPLETE banner summarizes top 3-5 urgent calibers in plain English
- [ ] KPI cards: Critical count, total estimated order cost, calibers at OK/healthy
- [ ] Table sorted by urgency → days of supply ascending
- [ ] Refreshes within existing TASK_DAILY_FORECAST weekly cycle
- [ ] f_reorder_recommendations has dbt tests (non-negative REORDER_QTY, valid URGENCY)

### Constraints Identified
- F_FORECAST is caliber-grain; F_INVENTORYVIEW is part_number-grain — join via INT_PRODUCT_ANALYST
- TASK_DAILY_FORECAST currently runs weekly (Sunday 4am UTC) — reorder recommendations will be weekly, not daily
- QTY_ON_HAND reflects Fishbowl state at last Airbyte sync — near-real-time but not live
- No historical reorder data to validate recommendations against (no ground truth)

### Out of Scope (Confirmed)
- Per-SKU recommendations
- Multi-vendor comparison
- Cost optimization across vendors
- Reorder approval workflow
- Historical recommendation tracking
- Overstock action recommendations

---

## Technical Notes for Define/Design

### Reorder Quantity Formula
```sql
-- Per caliber, next 30 days
demand_upper_30d = SUM(F_FORECAST.UPPER_BOUND) WHERE FORECAST_TYPE='caliber' AND next 30 days
qty_on_hand      = SUM(F_INVENTORYVIEW.QTY_ON_HAND) via INT_PRODUCT_ANALYST caliber join
qty_on_order     = SUM(F_INVENTORYVIEW.QTY_ON_ORDER) via INT_PRODUCT_ANALYST caliber join
reorder_qty      = GREATEST(0, demand_upper_30d - qty_on_hand - qty_on_order)
```

### Urgency Classification (consistent with Page 4)
```sql
CASE
  WHEN days_of_supply <= lead_time_days           THEN 'Critical'
  WHEN days_of_supply <= lead_time_days * 2       THEN 'Warning'
  WHEN days_of_supply > 90                        THEN 'Overstock'
  ELSE 'OK'
END
```

### Vendor Selection
```sql
-- Best vendor = lowest PRECISE_LEADTIME from F_POS for this caliber
-- PRECISE_LEADTIME already uses 3-tier cascade in F_POS
-- Take the most recently issued PO's vendor as tiebreaker
```

### Cost Estimate
- `gemini-2-5-flash`: ~$0.15/mo (same as Page 5)
- No new Snowflake compute pool or EAI needed

### Fast Follows (post-MVP)
1. **Daily Task refresh** — if purchasing team wants fresher recommendations
2. **Multi-vendor comparison** — top 3 vendors per caliber with lead time + cost
3. **Cost optimization** — minimize total order cost given lead time constraints
4. **Reorder history** — track whether recommendations were followed

---

## Session Summary

| Metric | Value |
|--------|-------|
| Questions Asked | 5 |
| Approaches Explored | 2 |
| Features Removed (YAGNI) | 6 |
| Validations Completed | 2 |

---

## Next Step

**Ready for:** `/define .claude/sdd/features/BRAINSTORM_REORDER_INTELLIGENCE.md`
