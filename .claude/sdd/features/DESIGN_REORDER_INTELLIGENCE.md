# DESIGN: Inventory Reorder Intelligence

> Technical design for `f_reorder_recommendations` Gold table + Page 4 "Reorder Recommendations" tab

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | REORDER_INTELLIGENCE |
| **Date** | 2026-04-16 |
| **Author** | design-agent |
| **DEFINE** | [DEFINE_REORDER_INTELLIGENCE.md](./DEFINE_REORDER_INTELLIGENCE.md) |
| **Status** | Ready for Build |

---

## Architecture Overview

```text
┌──────────────────────────────────────────────────────────────────────┐
│  ECS Fargate (dbt build, every 10 min)                               │
│                                                                      │
│  F_FORECAST (caliber UPPER_BOUND, weekly)                            │
│  F_INVENTORYVIEW (QTY_AVAILABLE + QTY_ON_ORDER, 10-min)             │
│  F_POS (PRECISE_LEADTIME + UNIT_COST, 10-min)                        │
│  INT_PRODUCT_ANALYST (CALIBER ↔ SKU bridge)                          │
│  D_VENDOR (VENDOR_ID → VENDOR_NAME)                                  │
│              │                                                       │
│              ▼ dbt build                                             │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  f_reorder_recommendations  (Gold table, transient)          │    │
│  │  1 row per caliber with forecast data                        │    │
│  │  CALIBER | REORDER_QTY | URGENCY | RECOMMENDED_VENDOR |     │    │
│  │  DAYS_OF_SUPPLY | LEAD_TIME_DAYS | ESTIMATED_ORDER_COST     │    │
│  └─────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
                    │
                    ▼ SQL via run_query()
┌──────────────────────────────────────────────────────────────────────┐
│  Streamlit Sales Dashboard — Page 4 (MODIFIED)                       │
│                                                                      │
│  Tabs: Stock-Out Risk | Caliber Forecast | Revenue Forecast          │
│        + Reorder Recommendations (NEW)                               │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ CORTEX.COMPLETE banner (gemini-2-5-flash, cached 10 min)     │   │
│  │ "9mm is critical: order 45,000 units from Vendor X (12d)..." │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐               │
│  │ Critical: 8  │ │ Est. Cost    │ │ OK: 94       │               │
│  │ calibers     │ │ $487K        │ │ calibers     │               │
│  └──────────────┘ └──────────────┘ └──────────────┘               │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ Reorder table (sorted Critical→Warning→OK→Overstock)         │   │
│  │ dark_dataframe() with currency + number formatting            │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

**Key insight on refresh cadence:**
- `f_reorder_recommendations` is a standard dbt Gold model — ECS Fargate rebuilds it every 10 min automatically
- No Task extension needed (A-003 assumption invalidated favorably)
- Demand side (UPPER_BOUND) updates weekly when TASK_DAILY_FORECAST runs
- Inventory side (QTY_AVAILABLE, QTY_ON_ORDER) updates every 10 min with Airbyte

---

## Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| `f_reorder_recommendations.sql` | Gold table — per-caliber reorder qty, urgency, vendor, cost | dbt (SQL, CTE pattern) |
| `f_reorder_recommendations.yml` | dbt schema tests + column descriptions | dbt YAML |
| `4_Forecast.py` (modified) | Add 4th tab with KPIs, table, LLM banner | Streamlit + SQL |
| `SNOWFLAKE.CORTEX.COMPLETE` | Generate plain-English purchasing summary | Cortex LLM (`gemini-2-5-flash`) |

---

## Key Decisions

### Decision 1: Standard dbt Gold Model — No Task Extension

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-16 |

**Context:** DEFINE assumed `f_reorder_recommendations` needed to be wired into `TASK_DAILY_FORECAST`. During design, we established that ECS Fargate already runs `dbt build` every 10 minutes, rebuilding all Gold tables.

**Choice:** `f_reorder_recommendations` is a standard Gold table — no Snowflake Task, no macro, no stored procedure. ECS Fargate builds it automatically on every cycle.

**Rationale:** The model reads from `F_FORECAST` (data changes weekly) and `F_INVENTORYVIEW` (data changes every 10 min). The dbt build picks up the latest state of both. No orchestration change needed.

**Alternatives Rejected:**
1. Add step to `TASK_DAILY_FORECAST` — unnecessary complexity; dbt build already handles it
2. Separate weekly Snowflake Task — over-engineering

**Consequences:**
- Inventory freshness every 10 min; demand freshness weekly — acceptable
- No changes to ECS entrypoint, EventBridge, or Task SQL

---

### Decision 2: Vendor Selection via ROW_NUMBER on F_POS

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-16 |

**Context:** Need to pick one "best" vendor per caliber from `F_POS` receipt history. F_POS has `PRECISE_LEADTIME` already computed via 3-tier cascade (vendor×part → vendor → part). Need to aggregate to caliber level via `INT_PRODUCT_ANALYST`.

**Choice:** Aggregate F_POS by (caliber, vendor_id) to get avg PRECISE_LEADTIME and avg UNIT_COST, then use `ROW_NUMBER() OVER (PARTITION BY caliber ORDER BY avg_lead_time ASC)` to pick the lowest-lead-time vendor.

**Rationale:** `PRECISE_LEADTIME` in F_POS already handles the 3-tier cascade fallback — we reuse that logic rather than re-implementing it. The QUALIFY/ROW_NUMBER pattern is already used throughout the project.

**Alternatives Rejected:**
1. Use `D_VENDOR.lead_time_days` directly — this is Fishbowl's stored lead time, not computed from actual receipt history; less accurate
2. Cost-optimized vendor — deferred to fast-follow (MVP uses lowest lead time)

**Consequences:**
- Vendor recommendation based on receipt history — may differ from `D_VENDOR.lead_time_days`
- Calibers with no PO history → NULL vendor, 14-day default lead time (same as Page 4)

---

### Decision 3: Modify 4_Forecast.py — No New File

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-16 |

**Context:** New tab must sit alongside existing tabs in Page 4. Options: modify `4_Forecast.py` or create a new page file.

**Choice:** Modify `4_Forecast.py`. Add two functions (`load_reorder_recommendations`, `generate_reorder_summary`) and extend the `st.tabs()` call with a 4th tab.

**Rationale:** Tabs share the same page — they must be in the same file. Consistent with how Pages 1-4 are structured (all logic in one file). The existing `load_stockout_risk()` and pattern of lazy tab loading serves as the direct template.

**Alternatives Rejected:**
1. New `5_Purchasing.py` page — user confirmed (b) new tab, not new page

**Consequences:**
- `4_Forecast.py` grows from ~330 lines to ~450-480 lines — within acceptable range
- Existing tabs (Stock-Out Risk, Caliber Forecast, Revenue Forecast) unaffected

---

### Decision 4: URGENCY Logic Consistent with Existing Page 4

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-16 |

**Context:** Page 4's `load_stockout_risk()` already computes a RISK_LEVEL with Critical/Warning/OK/Overstock. The new dbt model must use identical thresholds.

**Choice:** Copy the exact CASE logic from `load_stockout_risk()` into the dbt model — `days_of_supply <= lead_time_days` = Critical, `≤ lead_time_days * 2` = Warning, `> 90` = Overstock.

**Rationale:** Consistency — same caliber shouldn't show different risk levels between the two tabs. Users would be confused by divergent classifications.

**Consequences:**
- If Page 4's risk thresholds change, `f_reorder_recommendations` must be updated too
- Single source of truth for urgency lives in the Gold table (preferred over computing twice)

---

## File Manifest

| # | File | Action | Purpose | Agent | Dependencies |
|---|------|--------|---------|-------|--------------|
| 1 | `ammodepot/models/gold/f_reorder_recommendations.sql` | Create | Gold table — per-caliber reorder qty, urgency, vendor, cost | @dbt-expert | None |
| 2 | `ammodepot/models/gold/f_reorder_recommendations.yml` | Create | dbt schema tests + column descriptions | @dbt-expert | 1 |
| 3 | `streamlit_app/pages/4_Forecast.py` | Modify | Add 4th tab + 2 new functions | @streamlit-expert | 1 |

**Total Files:** 3 (2 create, 1 modify)

---

## Agent Assignment Rationale

| Agent | Files Assigned | Why This Agent |
|-------|----------------|----------------|
| @dbt-expert | 1, 2 | dbt Gold model CTE pattern, QUALIFY ROW_NUMBER, YAML test conventions |
| @streamlit-expert | 3 | SiS container runtime, `dark_dataframe()`, `apply_theme()`, dual-mode |

---

## Code Patterns

### Pattern 1: dbt Gold Model — f_reorder_recommendations.sql

```sql
with forecast_upper as (
    select
        caliber,
        sum(upper_bound)             as demand_upper_30d,
        avg(predicted_units)         as daily_avg_predicted
    from {{ ref('f_forecast') }}
    where forecast_type = 'caliber'
      and forecast_date > current_date()
      and forecast_date <= dateadd('day', 30, current_date())
    group by caliber
),

inventory_by_caliber as (
    select
        p.caliber,
        sum(coalesce(i.qty_available, 0)) as qty_available,
        sum(coalesce(i.qty_on_order, 0))  as qty_on_order
    from {{ ref('f_inventoryview') }} as i
    inner join {{ ref('int_product_analyst') }} as p
        on i.part_number = p.sku
    where p.caliber is not null
      and p.caliber != ''
    group by p.caliber
),

vendor_agg as (
    select
        p.caliber,
        po.vendor_id,
        round(avg(po.precise_leadtime), 0) as avg_lead_time,
        avg(po.unit_cost)                  as avg_unit_cost
    from {{ ref('f_pos') }} as po
    inner join {{ ref('int_product_analyst') }} as p
        on po.part_number = p.sku
    where po.precise_leadtime is not null
      and po.vendor_id is not null
      and p.caliber is not null
      and p.caliber != ''
    group by p.caliber, po.vendor_id
),

best_vendor as (
    select caliber, vendor_id, avg_lead_time, avg_unit_cost
    from vendor_agg
    qualify row_number() over (
        partition by caliber
        order by avg_lead_time asc nulls last
    ) = 1
),

reorder_calc as (
    select
        f.caliber,
        coalesce(i.qty_available, 0)                              as qty_available,
        coalesce(i.qty_on_order, 0)                               as qty_on_order,
        round(f.demand_upper_30d, 0)                              as demand_upper_30d,
        round(f.daily_avg_predicted, 1)                           as daily_avg_predicted,
        greatest(0,
            round(f.demand_upper_30d, 0)
            - coalesce(i.qty_available, 0)
            - coalesce(i.qty_on_order, 0)
        )                                                         as reorder_qty,
        coalesce(bv.avg_lead_time, 14)                            as lead_time_days,
        bv.vendor_id                                              as recommended_vendor_id,
        coalesce(bv.avg_unit_cost, 0)                             as avg_unit_cost,
        case
            when f.daily_avg_predicted > 0
            then round(coalesce(i.qty_available, 0)
                       / f.daily_avg_predicted, 1)
            else null
        end                                                       as days_of_supply,
        case
            when f.daily_avg_predicted > 0
            then dateadd('day',
                greatest(
                    round(coalesce(i.qty_available, 0)
                          / f.daily_avg_predicted)
                    - coalesce(bv.avg_lead_time, 14),
                    0
                )::int,
                current_date()
            )
            else null
        end                                                       as reorder_by
    from forecast_upper as f
    left join inventory_by_caliber as i on f.caliber = i.caliber
    left join best_vendor as bv on f.caliber = bv.caliber
),

final as (
    select
        rc.caliber                                                as CALIBER,
        rc.qty_available                                          as QTY_AVAILABLE,
        rc.qty_on_order                                           as QTY_ON_ORDER,
        rc.demand_upper_30d                                       as DEMAND_UPPER_30D,
        rc.daily_avg_predicted                                    as DAILY_AVG_PREDICTED,
        rc.reorder_qty                                            as REORDER_QTY,
        rc.lead_time_days                                         as LEAD_TIME_DAYS,
        rc.days_of_supply                                         as DAYS_OF_SUPPLY,
        rc.reorder_by                                             as REORDER_BY,
        case
            when rc.days_of_supply <= rc.lead_time_days           then 'Critical'
            when rc.days_of_supply <= rc.lead_time_days * 2       then 'Warning'
            when rc.days_of_supply > 90                           then 'Overstock'
            else 'OK'
        end                                                       as URGENCY,
        rc.recommended_vendor_id                                  as RECOMMENDED_VENDOR_ID,
        dv.vendor_name                                            as RECOMMENDED_VENDOR,
        rc.avg_unit_cost                                          as AVG_UNIT_COST,
        case
            when rc.reorder_qty > 0
            then round(rc.reorder_qty * rc.avg_unit_cost, 2)
            else 0
        end                                                       as ESTIMATED_ORDER_COST,
        current_timestamp()                                       as REFRESHED_AT
    from reorder_calc as rc
    left join {{ ref('d_vendor') }} as dv
        on rc.recommended_vendor_id = dv.vendor_id
)

select * from final
```

### Pattern 2: dbt YAML — f_reorder_recommendations.yml

```yaml
models:
  - name: f_reorder_recommendations
    description: >
      Per-caliber reorder recommendations. Combines F_FORECAST upper-bound
      30-day demand with current inventory and historical vendor lead times
      to produce system-generated reorder quantities, urgency levels, and
      recommended vendor. Refreshed every 10 min by ECS Fargate dbt build.
    columns:
      - name: CALIBER
        description: "Caliber identifier (primary key). One row per caliber."
        tests:
          - unique
          - not_null
      - name: REORDER_QTY
        description: >
          Recommended units to order: GREATEST(0, DEMAND_UPPER_30D
          - QTY_AVAILABLE - QTY_ON_ORDER). Always non-negative.
        tests:
          - assert_non_negative_values
      - name: URGENCY
        description: >
          Risk classification consistent with Page 4 Stock-Out Risk:
          Critical (days_of_supply <= lead_time), Warning (≤ 2x lead_time),
          Overstock (> 90 days), OK (otherwise).
        tests:
          - accepted_values:
              arguments:
                values: ['Critical', 'Warning', 'OK', 'Overstock']
      - name: QTY_AVAILABLE
        description: "Current available stock (from F_INVENTORYVIEW, caliber-aggregated)."
        tests:
          - assert_non_negative_values
      - name: QTY_ON_ORDER
        description: "Units already on order (from F_INVENTORYVIEW, caliber-aggregated)."
        tests:
          - assert_non_negative_values
      - name: DEMAND_UPPER_30D
        description: "Sum of F_FORECAST UPPER_BOUND over next 30 days — conservative demand estimate."
      - name: DAILY_AVG_PREDICTED
        description: "Average daily predicted units (point forecast) over next 30 days."
      - name: LEAD_TIME_DAYS
        description: "Avg vendor lead time for this caliber (days). Defaults to 14 if no PO history."
      - name: DAYS_OF_SUPPLY
        description: "QTY_AVAILABLE / DAILY_AVG_PREDICTED. NULL if no forecast demand."
      - name: REORDER_BY
        description: "Date by which reorder should be placed to avoid stock-out."
      - name: RECOMMENDED_VENDOR_ID
        description: "Fishbowl vendor_id with lowest avg lead time for this caliber."
      - name: RECOMMENDED_VENDOR
        description: "Vendor name (from D_VENDOR). NULL if no PO history."
      - name: AVG_UNIT_COST
        description: "Average unit cost from historical POs with recommended vendor."
      - name: ESTIMATED_ORDER_COST
        description: "REORDER_QTY × AVG_UNIT_COST. 0 if REORDER_QTY = 0."
        tests:
          - assert_non_negative_values
      - name: REFRESHED_AT
        description: "Timestamp when this row was last computed by dbt."
```

### Pattern 3: Page 4 Data Loading Functions (add to 4_Forecast.py)

```python
LLM_MODEL_REORDER = "gemini-2-5-flash"
LLM_CACHE_TTL_REORDER = 600  # seconds


@st.cache_data(ttl="10m", show_spinner=False)
def load_reorder_recommendations() -> pd.DataFrame:
    """Load pre-computed reorder recommendations from Gold table."""
    return run_query("""
        SELECT
            CALIBER, QTY_AVAILABLE, QTY_ON_ORDER,
            DEMAND_UPPER_30D, DAILY_AVG_PREDICTED,
            REORDER_QTY, LEAD_TIME_DAYS, DAYS_OF_SUPPLY,
            REORDER_BY, URGENCY,
            RECOMMENDED_VENDOR, AVG_UNIT_COST, ESTIMATED_ORDER_COST,
            REFRESHED_AT
        FROM F_REORDER_RECOMMENDATIONS
        ORDER BY
            CASE URGENCY
                WHEN 'Critical'  THEN 1
                WHEN 'Warning'   THEN 2
                WHEN 'OK'        THEN 3
                WHEN 'Overstock' THEN 4
                ELSE 5
            END,
            DAYS_OF_SUPPLY ASC NULLS LAST
    """)


@st.cache_data(ttl=LLM_CACHE_TTL_REORDER, show_spinner=False)
def generate_reorder_summary(reorder_json: str) -> str | None:
    """CORTEX.COMPLETE summary of top urgent reorder actions.

    Returns None on any failure — caller renders fallback.
    """
    try:
        prompt = (
            "You are a data analyst writing a 3-4 sentence purchasing brief "
            "for an ammunition retailer's operations manager. "
            "Be direct and numbers-forward — no filler, no greetings. "
            "Focus on the Critical calibers: name the caliber, units to order, "
            "recommended vendor, and days of supply remaining. "
            "Mention the total estimated order cost.\n\n"
            f"Reorder data (Critical and Warning only):\n{reorder_json}"
        )
        safe_prompt = prompt.replace("'", "''")
        df = run_query(f"""
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                '{LLM_MODEL_REORDER}',
                '{safe_prompt}'
            ) AS SUMMARY
        """)
        if not df.empty and df.iloc[0]["SUMMARY"]:
            raw = str(df.iloc[0]["SUMMARY"]).strip()
            if raw.startswith('"') and raw.endswith('"'):
                raw = raw[1:-1]
            return raw
        return None
    except Exception:
        return None
```

### Pattern 4: Tab Extension in Page 4

```python
# Change existing line:
tab_risk, tab_caliber, tab_revenue = st.tabs(
    ["Stock-Out Risk", "Caliber Forecast", "Revenue Forecast"]
)

# To:
tab_risk, tab_caliber, tab_revenue, tab_reorder = st.tabs(
    ["Stock-Out Risk", "Caliber Forecast", "Revenue Forecast",
     "Reorder Recommendations"]
)
```

### Pattern 5: Reorder Tab Rendering (add inside `with tab_reorder:`)

```python
with tab_reorder:
    reorder = load_reorder_recommendations()

    if reorder.empty:
        st.info("No reorder data available. Forecast data may not be populated yet.")
    else:
        # LLM summary — pass only Critical + Warning rows to keep prompt compact
        urgent = reorder[reorder["URGENCY"].isin(["Critical", "Warning"])]
        reorder_json = urgent.head(10).to_json(orient="records")
        summary = generate_reorder_summary(reorder_json)

        if summary:
            st.markdown(
                f'<div style="background:#1a2733; border-left:4px solid {ACCENT}; '
                f'border-radius:8px; padding:16px 20px; margin-bottom:16px; '
                f'color:{TEXT_PRIMARY}; font-size:14px; line-height:1.6;">'
                f"{summary}</div>",
                unsafe_allow_html=True,
            )
        else:
            st.caption("Purchasing summary unavailable.")

        # KPI cards
        critical_count = int((reorder["URGENCY"] == "Critical").sum())
        warning_count  = int((reorder["URGENCY"] == "Warning").sum())
        ok_count       = int((reorder["URGENCY"] == "OK").sum())
        total_cost     = float(
            reorder.loc[reorder["REORDER_QTY"] > 0, "ESTIMATED_ORDER_COST"].sum()
        )

        k1, k2, k3 = st.columns(3)
        k1.metric("Critical Calibers", critical_count)
        k2.metric("Est. Order Cost", f"${total_cost:,.0f}")
        k3.metric("OK / Healthy", ok_count)

        # Filter
        urgency_filter = st.selectbox(
            "Filter by urgency",
            ["All", "Critical", "Warning", "OK", "Overstock"],
            index=0,
            key="reorder_urgency_filter",
        )
        display = (
            reorder if urgency_filter == "All"
            else reorder[reorder["URGENCY"] == urgency_filter]
        )

        dark_dataframe(
            display[[
                "CALIBER", "URGENCY", "REORDER_QTY", "DAYS_OF_SUPPLY",
                "LEAD_TIME_DAYS", "REORDER_BY", "RECOMMENDED_VENDOR",
                "AVG_UNIT_COST", "ESTIMATED_ORDER_COST",
            ]],
            fmt={
                "REORDER_QTY":          "{:,.0f}",
                "DAYS_OF_SUPPLY":       "{:,.1f}",
                "LEAD_TIME_DAYS":       "{:,.0f}",
                "AVG_UNIT_COST":        "${:,.3f}",
                "ESTIMATED_ORDER_COST": "${:,.0f}",
            },
        )
```

---

## Data Flow

```text
1. ECS Fargate runs `dbt build` (every 10 min)
   │
   ▼
2. f_reorder_recommendations.sql executes
   ├── forecast_upper CTE: SUM(UPPER_BOUND) by caliber, next 30 days from F_FORECAST
   ├── inventory_by_caliber CTE: SUM(QTY_AVAILABLE, QTY_ON_ORDER) via INT_PRODUCT_ANALYST
   ├── best_vendor CTE: ROW_NUMBER on avg PRECISE_LEADTIME from F_POS
   └── final CTE: JOIN all, compute REORDER_QTY, URGENCY, ESTIMATED_ORDER_COST
   │
   ▼
3. F_REORDER_RECOMMENDATIONS table updated in AD_ANALYTICS.GOLD
   │
   ▼
4. User opens Page 4, clicks "Reorder Recommendations" tab
   │
   ▼
5. load_reorder_recommendations() — SQL SELECT from F_REORDER_RECOMMENDATIONS
   (cached 10 min, fast — reads pre-computed Gold table)
   │
   ├──→ KPI cards (critical_count, total_cost, ok_count)
   ├──→ Urgency filter selectbox
   └──→ urgent = filter to Critical + Warning rows
        │
        ▼
6. generate_reorder_summary(urgent.head(10).to_json())
   (CORTEX.COMPLETE, cached 10 min, returns None on failure)
   │
   ▼
7. Render: LLM banner → KPI cards → filter → dark_dataframe table
```

---

## Integration Points

| External System | Integration Type | Authentication |
|-----------------|-----------------|----------------|
| `AD_ANALYTICS.GOLD.F_REORDER_RECOMMENDATIONS` | SQL SELECT via `run_query()` | SiS: active session; Local: key-pair |
| `SNOWFLAKE.CORTEX.COMPLETE` | SQL function call via `run_query()` | Same session — no additional auth |

No new external integrations. No EAI changes. No new secrets. No Task changes.

---

## Testing Strategy

| Test Type | Scope | Method | Coverage |
|-----------|-------|--------|----------|
| dbt tests | `f_reorder_recommendations` | `dbt test --select f_reorder_recommendations` | CALIBER unique+not_null, REORDER_QTY ≥ 0, URGENCY accepted_values, ESTIMATED_ORDER_COST ≥ 0 |
| dbt build | Full model | `dbt build --select f_reorder_recommendations` | Compilation + data load |
| Manual — local | Page 4 tab | `streamlit run app.py` → click "Reorder Recommendations" | AT-004, AT-005, AT-007 |
| Manual — SiS | Page 4 tab | Deploy + open in Snowsight | AT-010 |
| Manual — LLM fallback | Graceful degradation | Set `LLM_MODEL_REORDER = "nonexistent"`, reload | AT-006 |
| Manual — data | Row count + spot check | Query `F_REORDER_RECOMMENDATIONS`, verify URGENCY distribution | AT-001, AT-002, AT-003 |

---

## Error Handling

| Error Type | Handling Strategy | Retry? |
|------------|-------------------|--------|
| `F_REORDER_RECOMMENDATIONS` empty | `st.info("No reorder data available...")` — consistent with existing tabs | No |
| CORTEX.COMPLETE fails | `generate_reorder_summary()` returns `None`; caption fallback | No |
| Caliber with no PO history | `RECOMMENDED_VENDOR = NULL`, `LEAD_TIME_DAYS = 14` (default) | N/A |
| Caliber with no inventory | `QTY_AVAILABLE = 0` via COALESCE; `REORDER_QTY = DEMAND_UPPER_30D` | N/A |
| Build duration increase | Monitor CloudWatch `/ecs/ammodepot-dbt` — alert threshold 8 min | N/A |

---

## Configuration

| Config Key | Type | Default | Description |
|------------|------|---------|-------------|
| `LLM_MODEL_REORDER` | str | `"gemini-2-5-flash"` | Cortex LLM model for purchasing summary |
| `LLM_CACHE_TTL_REORDER` | int | `600` | Cache TTL in seconds for LLM call |
| Lead time default | int | `14` (in SQL COALESCE) | Fallback when no PO history available |
| Forecast window | int | `30` (in SQL date filter) | Days of UPPER_BOUND to sum for demand |

---

## Security Considerations

- **No PII in LLM prompt** — caliber names, quantities, vendor names only (no customer data)
- **SQL injection** — prompt uses single-quote escaping; vendor/caliber values come from pre-computed Gold table (not user input)
- **RBAC** — same as Page 5; `DASHBOARD_VIEWER_ROLE` and `POWERBI_READONLY_ROLE` already have SELECT on Gold schema and CORTEX_USER role grant

---

## Observability

| Aspect | Implementation |
|--------|----------------|
| Build duration | CloudWatch metric `dbt_build_duration_seconds` — existing alert at 8 min |
| LLM cost | `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CONSUMPTION` (built-in) |
| Data freshness | `REFRESHED_AT` column in `F_REORDER_RECOMMENDATIONS` — visible in tab |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-16 | design-agent | Initial version |

---

## Next Step

**Ready for:** `/build .claude/sdd/features/DESIGN_REORDER_INTELLIGENCE.md`
