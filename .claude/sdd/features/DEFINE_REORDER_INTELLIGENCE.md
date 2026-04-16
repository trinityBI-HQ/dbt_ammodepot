# DEFINE: Inventory Reorder Intelligence

> New dbt Gold table + Page 4 tab that tells the purchasing team how much to order per caliber and from which vendor, powered by ML forecast upper bounds

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | REORDER_INTELLIGENCE |
| **Date** | 2026-04-16 |
| **Author** | define-agent |
| **Status** | Ready for Design |
| **Clarity Score** | 15/15 |
| **Brainstorm** | `.claude/sdd/features/BRAINSTORM_REORDER_INTELLIGENCE.md` |
| **AI Roadmap** | Phase 5 (first prescriptive phase) |

---

## Problem Statement

The purchasing team can see *when* calibers need reordering via the existing Page 4 stock-out risk table, but must manually estimate *how much* to order and *from which vendor*. There is no system-generated reorder quantity or vendor recommendation, creating guesswork in purchasing decisions that risks stock-outs (under-ordering) or capital lock-up (over-ordering).

---

## Target Users

| User | Role | Pain Point |
|------|------|------------|
| Purchasing/ops team | Makes weekly restocking decisions | Must manually estimate reorder qty from Page 4 — no system recommendation, relies on intuition |
| Management | Approves purchasing budget | No visibility into estimated total purchasing cost needed this week |

---

## Goals

| Priority | Goal |
|----------|------|
| **MUST** | Create `f_reorder_recommendations` Gold table with per-caliber: reorder qty, urgency, recommended vendor, estimated order cost |
| **MUST** | Add "Reorder Recommendations" tab to Page 4 alongside existing tabs |
| **MUST** | Table sorted by urgency → days of supply ascending |
| **MUST** | 3 KPI cards: Critical calibers count, total estimated order cost, calibers at OK |
| **MUST** | CORTEX.COMPLETE banner summarizing top 3-5 urgent calibers in plain English |
| **MUST** | Refresh within existing `TASK_DAILY_FORECAST` weekly cycle (no new Task) |
| **MUST** | `f_reorder_recommendations` has dbt tests (non-negative REORDER_QTY, valid URGENCY) |
| **SHOULD** | Degrade gracefully if CORTEX.COMPLETE fails — table + KPIs render without the banner |
| **COULD** | Show estimated order cost total in the tab header |

---

## Success Criteria

- [ ] `f_reorder_recommendations` populates with one row per caliber that has forecast data, current stock, and lead time
- [ ] `REORDER_QTY = GREATEST(0, DEMAND_UPPER_30D - QTY_AVAILABLE - QTY_ON_ORDER)` — non-negative, accounts for in-transit stock
- [ ] `URGENCY` classification matches Page 4's existing labels: Critical / Warning / OK / Overstock
- [ ] `RECOMMENDED_VENDOR` populated from `F_POS` — vendor with lowest `PRECISE_LEADTIME` for that caliber
- [ ] `ESTIMATED_ORDER_COST = REORDER_QTY × AVG_UNIT_COST` from `F_POS`
- [ ] New "Reorder Recommendations" tab appears in Page 4 tab strip
- [ ] CORTEX.COMPLETE banner generates in <5s on cache miss, served from cache within 10 min
- [ ] Page 4 existing tabs (Stock-Out Risk, Caliber Forecast, Revenue Forecast) unaffected
- [ ] dbt build passes with 0 errors on new model + tests
- [ ] Works in both local dev and SiS container runtime

---

## Acceptance Tests

| ID | Scenario | Given | When | Then |
|----|----------|-------|------|------|
| AT-001 | Table populates | `F_FORECAST`, `F_INVENTORYVIEW`, `F_POS` all have data | dbt build runs | `f_reorder_recommendations` has rows with REORDER_QTY ≥ 0 |
| AT-002 | Reorder qty floors at 0 | A caliber has QTY_AVAILABLE + QTY_ON_ORDER > DEMAND_UPPER_30D | Model runs | REORDER_QTY = 0 (not negative) |
| AT-003 | Critical urgency correct | A caliber's DAYS_OF_SUPPLY ≤ LEAD_TIME_DAYS | Model runs | URGENCY = 'Critical' |
| AT-004 | New tab renders | User navigates to Page 4 | User clicks "Reorder Recommendations" tab | KPI cards, table, LLM banner all render |
| AT-005 | Existing tabs unaffected | All existing Page 4 tabs work | New tab added | Stock-Out Risk, Caliber Forecast, Revenue Forecast tabs unchanged |
| AT-006 | LLM graceful degradation | CORTEX.COMPLETE unavailable | Tab loads | KPI cards and table render; banner shows fallback caption |
| AT-007 | Vendor recommendation populated | F_POS has lead time data for caliber's parts | Model runs | RECOMMENDED_VENDOR is not null for calibers with PO history |
| AT-008 | Null vendor handled | A caliber has no F_POS lead time data | Model runs | RECOMMENDED_VENDOR = NULL (no crash); LEAD_TIME_DAYS falls back to 14 |
| AT-009 | dbt tests pass | Model built | `dbt test --select f_reorder_recommendations` | All tests green |
| AT-010 | SiS compatibility | Tab deployed via snow streamlit deploy | User opens Page 4 in Snowsight | New tab renders without Plotly/serialization errors |

---

## Out of Scope

- **Per-SKU recommendations** — caliber grain matches actual purchasing workflow
- **Multi-vendor comparison** — one best vendor (lowest lead time) sufficient for MVP
- **Cost optimization across vendors** — unit cost in F_POS but vendor comparison adds complexity; deferred
- **Reorder approval workflow** — no email/workflow infra
- **Historical recommendation tracking** — track whether recommendations were followed; deferred
- **Overstock action recommendations** — flag overstock (already in Page 4), don't prescribe action yet
- **New Snowflake Task** — reorder refresh runs within existing `TASK_DAILY_FORECAST`
- **New Streamlit page** — tab in existing Page 4 only

---

## Constraints

| Type | Constraint | Impact |
|------|------------|--------|
| Data | F_INVENTORYVIEW is part_number grain; F_FORECAST is caliber grain | Must join via `INT_PRODUCT_ANALYST` (CALIBER → SKU → PART_NUMBER bridge) |
| Data | F_INVENTORYVIEW column is `QTY_AVAILABLE` (not `QTY_ON_HAND`) | Formula uses `QTY_AVAILABLE` — critical naming difference |
| Data | F_FORECAST has `UPPER_BOUND` as daily values | Must SUM over 30-day window to get `DEMAND_UPPER_30D` |
| Data | F_POS lead time may be sparse for some calibers | `PRECISE_LEADTIME` can be NULL — default to 14 days (same as Page 4 fallback) |
| Refresh | `TASK_DAILY_FORECAST` runs weekly (Sunday 4am UTC) | Reorder recommendations will be weekly, not daily |
| Build | ECS Fargate at ~60% of 10-min schedule window | New Gold table adds ~10-20s — monitor build duration |
| Architecture | No per-model `{{ config() }}` blocks | Materialization configured in `dbt_project.yml` |
| Compatibility | SiS container runtime constraints | No new Python dependencies; `run_query()` for LLM call |

---

## Technical Context

| Aspect | Value | Notes |
|--------|-------|-------|
| **Deployment Location** | `ammodepot/models/gold/f_reorder_recommendations.sql` + `streamlit_app/pages/4_Forecast.py` | New dbt model + modify existing page |
| **KB Domains** | snowflake (Cortex LLM), dbt-core, streamlit | `cortex-ml-functions.md`, dbt conventions |
| **IaC Impact** | None | No new warehouses, pools, or RBAC changes needed |

**Data Sources and Join Path:**

| Table | Grain | Key Columns | Role |
|-------|-------|-------------|------|
| `F_FORECAST` | caliber × date | `CALIBER`, `UPPER_BOUND`, `FORECAST_TYPE='caliber'`, next 30 days | Demand upper bound |
| `INT_PRODUCT_ANALYST` | product | `CALIBER`, `SKU` | Bridge: caliber → part_number |
| `F_INVENTORYVIEW` | part_number | `PART_NUMBER`, `QTY_AVAILABLE`, `QTY_ON_ORDER`, `PART_COST` | Current stock |
| `F_POS` | receipt item | `PART_NUMBER`, `VENDOR_ID`, `PRECISE_LEADTIME`, `UNIT_COST` | Lead times + costs |
| `D_VENDOR` | vendor | `VENDOR_ID`, vendor name | Vendor name lookup |

**Join path:**
```
F_FORECAST.CALIBER
  → INT_PRODUCT_ANALYST.CALIBER  (aggregate stock by CALIBER via SKU)
  → F_INVENTORYVIEW.PART_NUMBER  (via INT_PRODUCT_ANALYST.SKU)
  → F_POS.PART_NUMBER            (best vendor per caliber by lowest PRECISE_LEADTIME)
  → D_VENDOR.VENDOR_ID           (vendor name)
```

**Reorder formula:**
```sql
demand_upper_30d = SUM(UPPER_BOUND) from F_FORECAST
                   WHERE FORECAST_TYPE = 'caliber'
                   AND FORECAST_DATE BETWEEN CURRENT_DATE()+1 AND CURRENT_DATE()+30

qty_available    = SUM(F_INVENTORYVIEW.QTY_AVAILABLE) via caliber join
qty_on_order     = SUM(F_INVENTORYVIEW.QTY_ON_ORDER)  via caliber join

reorder_qty      = GREATEST(0, demand_upper_30d - qty_available - qty_on_order)

days_of_supply   = CASE WHEN daily_avg_predicted > 0
                        THEN qty_available / daily_avg_predicted
                        ELSE NULL END

urgency          = CASE WHEN days_of_supply <= lead_time_days       THEN 'Critical'
                        WHEN days_of_supply <= lead_time_days * 2   THEN 'Warning'
                        WHEN days_of_supply > 90                    THEN 'Overstock'
                        ELSE 'OK' END
```

**LLM Configuration:**

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Model | `gemini-2-5-flash` | Same as Page 5 — consistent, ~$0.15/mo |
| Fallback | `llama3.1-70b` | Native us-east-1 |
| Cache TTL | 600s (10 min) | Matches dbt build cadence |
| Prompt focus | Top 3-5 critical calibers with qty + vendor + days of supply | Numbers-forward, actionable |

---

## Assumptions

| ID | Assumption | If Wrong, Impact | Validated? |
|----|------------|------------------|------------|
| A-001 | `INT_PRODUCT_ANALYST.SKU` maps to `F_INVENTORYVIEW.PART_NUMBER` for most calibers | Some calibers may have no inventory rows — LEFT JOIN + COALESCE(qty, 0) handles it | [ ] |
| A-002 | `F_FORECAST` UPPER_BOUND is always ≥ PREDICTED_UNITS ≥ 0 for caliber forecasts | Near-zero forecasts give near-zero reorder qty — acceptable outcome | [ ] |
| A-003 | `TASK_DAILY_FORECAST` can be extended to refresh `f_reorder_recommendations` | If Task has time constraints, need separate Task or macro | [ ] |
| A-004 | F_POS NULL PRECISE_LEADTIME defaults to 14 days | Already validated — Page 4 uses same fallback | [x] |
| A-005 | Adding 1 new Gold model stays within 10-min ECS window | Current ~6 min; 1 Gold table adds ~10-20s | [ ] |

---

## Clarity Score Breakdown

| Element | Score (0-3) | Notes |
|---------|-------------|-------|
| Problem | 3 | Specific: no reorder qty or vendor recommendation despite having all required data |
| Users | 3 | Two personas with concrete pain points |
| Goals | 3 | MUST/SHOULD/COULD prioritized; all measurable |
| Success | 3 | 10 testable acceptance criteria with exact formula and column names |
| Scope | 3 | 7 items explicitly excluded; critical naming correction (`QTY_AVAILABLE`) documented |
| **Total** | **15/15** | |

---

## Open Questions

None — ready for Design. Validate during Design/Build:
- A-001: Verify INT_PRODUCT_ANALYST.SKU → F_INVENTORYVIEW.PART_NUMBER join completeness in prod
- A-003: Confirm TASK_DAILY_FORECAST can be extended for reorder refresh
- A-005: Monitor build duration after adding new Gold model

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-16 | define-agent | Initial version from BRAINSTORM_REORDER_INTELLIGENCE.md |

---

## Next Step

**Ready for:** `/design .claude/sdd/features/DEFINE_REORDER_INTELLIGENCE.md`
