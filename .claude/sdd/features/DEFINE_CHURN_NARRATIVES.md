# DEFINE: Customer Churn Narratives with CORTEX.COMPLETE

> New Streamlit dashboard page showing customer segment health with KPI cards, segment/at-risk tables, and a CORTEX.COMPLETE executive summary banner

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | CHURN_NARRATIVES |
| **Date** | 2026-04-15 |
| **Author** | define-agent |
| **Status** | Ready for Design |
| **Clarity Score** | 15/15 |
| **Brainstorm** | `.claude/sdd/features/BRAINSTORM_CHURN_NARRATIVES.md` |
| **AI Roadmap** | Phase 4 (follows Analyst, Forecasting, Anomaly Detection) |

---

## Problem Statement

Dashboard users have no dedicated view of customer health. Segment distributions, at-risk customer identification, and churn trends are locked inside the `D_CUSTOMER_SEGMENTATION` table with 17 RFM classification codes that require manual interpretation. Operations managers must run ad-hoc queries or ask the analyst chatbot to understand customer retention risk.

---

## Target Users

| User | Role | Pain Point |
|------|------|------------|
| Ops/management | Decision-makers reviewing daily sales performance | No single view of customer churn risk across RFM segments; must mentally decode F3/R2 = "Nurture Potential" |
| Dashboard viewers | Self-serve Streamlit users (DASHBOARD_VIEWER_ROLE, POWERBI_READONLY_ROLE) | Cannot see which customer segments are growing or shrinking without writing SQL |

---

## Goals

| Priority | Goal |
|----------|------|
| **MUST** | Render Page 5 "Customer Intelligence" with segment KPI cards and tables that work without LLM dependency |
| **MUST** | Display all 17 RFM customer classifications with current customer count and total lifetime value |
| **MUST** | Show top 10 highest-value customers in concerning segments (At-Risk Regular, Lost Buyer, Inactive, Inactive Regular, Lapsed Buyer, Losing 1-Time Buyer) |
| **MUST** | Generate a 3-4 sentence executive summary via CORTEX.COMPLETE that ties segment data together |
| **MUST** | Match existing dark theme and dashboard patterns (KPI cards, `dark_dataframe()`, full-width CSS) |
| **MUST** | Work in both local dev and SiS container runtime |
| **SHOULD** | Cache LLM call with `st.cache_data(ttl=600)` to control cost (~$0.60/mo target) |
| **SHOULD** | Degrade gracefully if CORTEX.COMPLETE fails — page renders structured data without the narrative banner |
| **COULD** | Include a segment distribution Plotly bar chart (horizontal, sorted by count) |

---

## Success Criteria

- [ ] Page 5 renders segment KPI cards and both tables within 3s (no LLM dependency for structural content)
- [ ] CORTEX.COMPLETE executive summary generates in <5s on cache miss, served from cache on subsequent loads within 10 min
- [ ] Top 10 at-risk customers table shows RANK_ID, CUSTOMER_CLASSIFICATION, TOTAL_REVENUE, DAYS_SINCE_LAST_PURCHASE
- [ ] All 17 CUSTOMER_CLASSIFICATION values displayed in segment health table with customer count and SUM(TOTAL_REVENUE)
- [ ] KPI cards show: Total Customers, At-Risk Count, Lost Buyers, and a health metric (e.g., % in positive segments)
- [ ] Dark theme consistent: `#1E1E1E` background, `apply_theme()` on any Plotly charts, `dark_dataframe()` for tables
- [ ] Page works in SiS container runtime (Streamlit 1.55+, `sales_dashboard_pool`) and local dev
- [ ] If CORTEX.COMPLETE call fails, page displays a subtle fallback message instead of crashing

---

## Acceptance Tests

| ID | Scenario | Given | When | Then |
|----|----------|-------|------|------|
| AT-001 | Page loads with all segments | `D_CUSTOMER_SEGMENTATION` has data | User navigates to Page 5 | KPI cards render, segment health table shows all 17 classifications, top at-risk table shows up to 10 rows |
| AT-002 | Executive summary generates | CORTEX.COMPLETE is available | Page 5 loads (cache miss) | A 3-4 sentence summary banner appears above KPI cards within 5s, referencing actual segment counts |
| AT-003 | LLM graceful degradation | CORTEX.COMPLETE is unavailable or errors | Page 5 loads | KPI cards and tables render normally; summary banner shows "Executive summary unavailable" or is hidden |
| AT-004 | Cache hit on reload | User reloads Page 5 within 10 minutes | Page 5 re-renders | Same executive summary displayed instantly (no LLM call), tables re-query (fast SQL) |
| AT-005 | Empty segment handling | A classification has 0 customers (e.g., Unclassified) | Page 5 loads | Classification still appears in segment table with count=0, no errors |
| AT-006 | SiS runtime compatibility | App deployed to `sales_dashboard_pool` via `snow streamlit deploy` | User opens Page 5 in Snowsight | All components render correctly — no Plotly serialization errors, no import failures |
| AT-007 | Local dev compatibility | Developer runs `streamlit run app.py` locally | Page 5 loads via local Snowflake connection | All components render identically to SiS (same queries, same layout) |
| AT-008 | Concerning segments identified | Customers exist in At-Risk Regular, Lost Buyer, Inactive, Lapsed Buyer | Page 5 loads | Top at-risk table filters to only concerning segments, sorted by TOTAL_REVENUE descending |

---

## Out of Scope

- **Per-customer narrative generation** — deferred; 20x token cost for marginal insight gain
- **MoM segment deltas** — requires `dbt snapshot` of `D_CUSTOMER_SEGMENTATION` that doesn't exist; separate task
- **Campaign recommendations** — marketing tooling, not ops dashboard
- **Cohort retention visualization** — data exists in `f_cohort` but is a separate concern; natural future expansion
- **Email/export functionality** — no email infra; screenshot sufficient for MVP
- **Modifications to Pages 1-4** — Page 5 is additive only
- **New dbt models** — all required data exists in `D_CUSTOMER_SEGMENTATION`, `F_SALES`, `D_CUSTOMER`

---

## Constraints

| Type | Constraint | Impact |
|------|------------|--------|
| Technical | `D_CUSTOMER_SEGMENTATION` has no historical snapshots | MoM deltas impossible without dbt snapshot; MVP shows current-state only |
| Technical | CORTEX.COMPLETE billed per-token (Cortex LLM credits) | Must cache aggressively; `st.cache_data(ttl=600)` caps cost at ~$0.60/mo |
| Technical | SiS container runtime constraints | Plotly: `go.Figure` + `.tolist()` only; no `px.*`; tables via `dark_dataframe()` not `st.dataframe` |
| Technical | Existing `utils/db.py` `run_query()` function | All SQL flows through this; no separate connection needed |
| Technical | LLM model availability in Snowflake region | Must verify `llama3.1-70b` is available in account's region; fallback to `mistral-large` |
| Infra | No incremental infra cost | Shares `sales_dashboard_pool` (already running, ~$5/mo); no new compute pool or EAI needed |
| Compatibility | Existing Pages 1-4 must not be modified | Page 5 is additive; no changes to imports, session state keys, or shared utils |

---

## Technical Context

| Aspect | Value | Notes |
|--------|-------|-------|
| **Deployment Location** | `streamlit_app/pages/5_Customer_Intelligence.py` | New page in existing Sales Dashboard app |
| **KB Domains** | snowflake (Cortex ML functions, Cortex LLM), streamlit | Patterns: `cortex-ml-functions.md`, SiS compatibility notes in CLAUDE.md |
| **IaC Impact** | None | Shares existing compute pool, EAI, and RBAC grants |

**Data Sources (all existing, no changes):**

| Table | Schema | Key Columns Used |
|-------|--------|-----------------|
| `D_CUSTOMER_SEGMENTATION` | `AD_ANALYTICS.GOLD` | `RANK_ID`, `CUSTOMER_CLASSIFICATION`, `TOTAL_REVENUE`, `DAYS_SINCE_LAST_PURCHASE`, `NUMBER_OF_PURCHASES`, `FREQUENCY`, `RECENCY`, `VALUE`, `CUSTOMER_GROUP` |
| `F_SALES` | `AD_ANALYTICS.GOLD` | Only if needed for cross-reference (e.g., most-purchased category per at-risk customer) |
| `D_CUSTOMER` | `AD_ANALYTICS.GOLD` | Not needed for MVP — demographics not in scope |

**LLM Configuration:**

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Model | `gemini-2-5-flash` | Strong structured-to-narrative output, good instruction following, ~$0.15/mo at expected usage |
| Fallback model | `llama3.1-70b` | Native us-east-1 fallback if Gemini cross-region routing has issues |
| Cache TTL | 600s (10 min) | Matches dbt build cadence |
| Max output tokens | ~150 | 3-4 sentence executive summary |
| Prompt style | Structured data in, executive summary out | Numbers-forward, no filler |

**Estimated cost:**
- ~500 input + ~100 output tokens per call
- `gemini-2-5-flash`: $0.45/M input, $3.75/M output
- 20-30 cache misses/day realistic → ~$0.005/day → **~$0.15/month**

---

## Assumptions

| ID | Assumption | If Wrong, Impact | Validated? |
|----|------------|------------------|------------|
| A-001 | `gemini-2-5-flash` is available via CORTEX.COMPLETE (cross-region routed to us-east-1) | Switch to `llama3.1-70b` (native us-east-1); no cost/quality impact | [ ] |
| A-002 | `D_CUSTOMER_SEGMENTATION` is reasonably sized (thousands, not millions of rows) | Aggregation query may need optimization; unlikely given customer-level grain | [ ] |
| A-003 | CORTEX.COMPLETE works from SiS container runtime via `run_query()` | If blocked, would need Snowpark `session.sql()` variant or REST fallback | [ ] |
| A-004 | Existing RBAC grants (DASHBOARD_VIEWER_ROLE, POWERBI_READONLY_ROLE) include access to CORTEX functions | If not, need `GRANT USAGE ON FUNCTION SNOWFLAKE.CORTEX.COMPLETE` or similar | [ ] |
| A-005 | `st.cache_data` works with CORTEX.COMPLETE result (string return type) | Should work — it's just a string; but verify no serialization issues | [ ] |

---

## Concerning Segments (Reference)

The following `CUSTOMER_CLASSIFICATION` values are considered "concerning" for the at-risk table:

| Classification | RFM Pattern | Why Concerning |
|---|---|---|
| At-Risk Regular | F4-F5, R3 | High-frequency buyers going quiet |
| Lost Buyer | F4-F5, R1 | Previously loyal, now gone |
| Inactive | F1, R1 | One-time buyers who never returned |
| Inactive Regular | F4-F5, R2 | Multi-purchase customers drifting away |
| Lapsed Buyer | F2-F3, R1-R2 | Moderate buyers who stopped |
| Losing 1-Time Buyer | F1, R2-R3 | Single-purchase, slipping away |

**Positive segments** (for KPI health metric): Super Engaged, Highly Engaged, Active Loyalist, Engaged Regular, New Buyer, New Active Buyer.

---

## Clarity Score Breakdown

| Element | Score (0-3) | Notes |
|---------|-------------|-------|
| Problem | 3 | Specific: no customer health view, RFM codes require interpretation |
| Users | 3 | Two personas identified with concrete pain points |
| Goals | 3 | MUST/SHOULD/COULD prioritized; all measurable |
| Success | 3 | 8 measurable criteria with specific thresholds (latency, counts, theme) |
| Scope | 3 | 7 items explicitly excluded with rationale; 8 acceptance tests |
| **Total** | **15/15** | |

---

## Open Questions

None — ready for Design. The following should be validated during Design/Build:
- A-001: Verify `llama3.1-70b` availability in Snowflake region
- A-003: Verify CORTEX.COMPLETE callable from SiS container runtime via `run_query()`
- A-004: Verify RBAC grants for Cortex functions

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-15 | define-agent | Initial version from BRAINSTORM_CHURN_NARRATIVES.md |

---

## Next Step

**Ready for:** `/design .claude/sdd/features/DEFINE_CHURN_NARRATIVES.md`
