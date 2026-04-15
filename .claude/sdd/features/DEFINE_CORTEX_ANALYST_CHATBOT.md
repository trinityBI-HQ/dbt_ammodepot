# DEFINE: Cortex Analyst Text-to-SQL Chatbot

> Natural language query interface for Ammunition Depot's Gold layer, powered by Snowflake Cortex Analyst and deployed as a standalone Streamlit SiS app

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | CORTEX_ANALYST_CHATBOT |
| **Date** | 2026-04-14 |
| **Author** | define-agent |
| **Status** | Ready for Design |
| **Clarity Score** | 15/15 |
| **Source** | [BRAINSTORM_CORTEX_ANALYST_CHATBOT.md](BRAINSTORM_CORTEX_ANALYST_CHATBOT.md) |

---

## Problem Statement

Operations and executive users at Ammunition Depot cannot answer ad-hoc analytical questions without requesting custom SQL from the data team. The existing Streamlit dashboards (3 pages: Today/Yesterday, Sales Overview, Inventory) cover structured KPIs but cannot handle freeform questions like "How many customers are At-Risk Regular?", "Which vendors have the longest lead times?", or "Revenue by use-type category this month." Three Gold models (`d_customer_segmentation`, `f_cohort`, `f_shippment`) have no dashboard exposure at all. A natural language chatbot would enable self-service querying without external API dependencies.

---

## Target Users

| User | Role | Pain Point |
|------|------|------------|
| Operations team (Seth + warehouse crew) | Inventory management, order fulfillment, vendor coordination | Cannot quickly answer inventory/PO/vendor questions without writing SQL or waiting for the data team. Need precise answers: exact counts, specific SKUs, overdue POs |
| Executive / ownership | Business strategy, margin oversight, customer retention | Cannot get ad-hoc margin, customer segment, or trend answers without pre-built dashboard views. Need aggregations and comparisons: "How are we doing vs last month?" |

---

## Goals

What success looks like (prioritized):

| Priority | Goal |
|----------|------|
| **MUST** | Users can ask natural language questions and receive correct SQL + results for 6 Gold models |
| **MUST** | Semantic View covers `f_sales`, `f_inventoryview`, `f_pos`, `d_product`, `d_vendor`, `d_customer_segmentation` with accurate column mappings, metrics, and relationships |
| **MUST** | 10 verified queries (golden questions) pre-validated to ensure accuracy on the most common questions |
| **MUST** | Deployed as a separate Streamlit SiS app on container runtime with CI/CD |
| **MUST** | RBAC enforced: `DASHBOARD_VIEWER_ROLE` + `POWERBI_READONLY_ROLE` can use the chatbot; only Gold layer accessible |
| **SHOULD** | Generated SQL is displayed alongside results so users can learn and verify |
| **SHOULD** | Follow-up suggestions rendered as clickable buttons for guided exploration |
| **SHOULD** | Dark theme consistent with existing Sales Dashboard (`#1E1E1E` background) |
| **COULD** | Multi-turn conversation context (prior questions influence follow-ups within same session) |
| **COULD** | Onboarding questions displayed on first visit (derived from `use_as_onboarding_question` verified queries) |

---

## Success Criteria

Measurable outcomes (must include numbers):

- [ ] **Accuracy**: 8/10 golden questions return correct SQL and matching results on first attempt
- [ ] **Safety**: Out-of-scope questions gracefully refused — no hallucinated SQL generated
- [ ] **Security**: SQL injection attempts blocked (Cortex generates SELECT-only; no DML)
- [ ] **Performance**: Median end-to-end response time < 5 seconds (API call + SQL execution + rendering)
- [ ] **RBAC**: `DASHBOARD_VIEWER_ROLE` can use chatbot; cannot access Silver, Bronze, or LAKEHOUSE_LANDING schemas
- [ ] **Deployment**: Deployed to SiS container runtime via GitHub Actions with automatic EAI re-attachment
- [ ] **Cost**: Cortex Analyst credit consumption < $50/month at moderate usage (50-200 questions/day)
- [ ] **Dashboard parity**: Answers to golden questions 1, 2, 6, 7 must match corresponding Streamlit dashboard KPI values within rounding tolerance

---

## Acceptance Tests

| ID | Scenario | Given | When | Then |
|----|----------|-------|------|------|
| AT-001 | Simple aggregation | User is on the chatbot page | User asks "What is total revenue today?" | Cortex returns SQL with `SUM(ROW_TOTAL)` filtered to today; result matches Page 1 Net Sales KPI |
| AT-002 | Dimension lookup | User is on the chatbot page | User asks "How many units of 9mm are in stock?" | Cortex returns SQL joining `f_inventoryview` + `d_product` with caliber filter; result matches Page 3 inventory |
| AT-003 | Customer segmentation (no dashboard) | User is on the chatbot page | User asks "How many customers are At-Risk Regular?" | Cortex returns `COUNT` from `d_customer_segmentation WHERE CUSTOMER_CLASSIFICATION = 'At-Risk Regular'` |
| AT-004 | Vendor lead times | User is on the chatbot page | User asks "Which vendors have the longest lead times?" | Cortex returns SQL grouping by vendor_name, ordering by AVG(precise_leadtime) DESC |
| AT-005 | Open POs | User is on the chatbot page | User asks "Show me open POs not yet received" | Cortex returns SQL with `datereceived IS NULL AND quantity_to_fulfill > 0` |
| AT-006 | Out-of-scope question | User is on the chatbot page | User asks "What's the weather today?" | Cortex returns text explanation that it can only answer questions about sales, inventory, products, vendors, and customers — no SQL generated |
| AT-007 | SQL injection attempt | User is on the chatbot page | User enters `'; DROP TABLE f_sales; --` | Cortex either refuses or generates safe SELECT-only SQL; no DML executed |
| AT-008 | Follow-up suggestions | User asks any valid question | Cortex responds with answer | Response includes `suggestions` array rendered as clickable buttons |
| AT-009 | Clear conversation | User has asked 3+ questions | User clicks "Clear conversation" in sidebar | Session state resets; message history cleared; fresh start |
| AT-010 | RBAC enforcement | User authenticates as `DASHBOARD_VIEWER_ROLE` | User asks a question | SQL executes against Gold schema only; no Silver/Bronze tables accessible |
| AT-011 | Performance | User asks 20 consecutive questions | Measure end-to-end time per question | Median < 5 seconds; P95 < 10 seconds |
| AT-012 | SiS deployment | Code pushed to `main` with changes in `streamlit_analyst/` | GitHub Actions triggers | App deployed to `AD_ANALYTICS.OPS.ANALYST` on `sales_dashboard_pool`; EAI re-attached if needed |

---

## Out of Scope

Explicitly NOT included in this feature (Phase 1):

- **Cross-model calculated metrics** — stock-out prediction (f_sales + f_inventoryview + f_pos), margin by customer segment (f_sales + d_customer_segmentation) → Phase 2
- **Cortex ML functions** — `SNOWFLAKE.ML.FORECAST` for demand prediction, `SNOWFLAKE.ML.ANOMALY_DETECTION` for alerts → Phases 2-3
- **Cortex `COMPLETE()`** — narrative summaries, trend explanations → Phase 4
- **Chart/visualization generation** — chatbot returns tables only; users have existing dashboards for charts → Phase 3
- **Product affinity engine** — "frequently bought together" analysis → Phase 5
- **Persistent conversation history** — no cross-session memory; each visit starts fresh
- **Streaming responses** — full response returned at once (2-5s latency acceptable)
- **Export functionality** — beyond built-in `st.dataframe` download button
- **Separate compute pool** — shared `sales_dashboard_pool`; revisit only if contention observed
- **7 deferred Gold models** — `f_cohort`, `f_cohort_detailed`, `f_shippment`, `d_store`, `d_customer`, `d_product_bundle`, `f_sales_realtime` added in later phases

---

## Constraints

| Type | Constraint | Impact |
|------|------------|--------|
| **API** | No external LLM API keys — client will not provide them | All AI must use Snowflake Cortex (billed as compute credits) |
| **Compute** | Shared `sales_dashboard_pool` (CPU_X64_XS, 1 node, auto-suspend 300s) | Chatbot must not starve the production Sales Dashboard; test concurrent usage |
| **Runtime** | SiS container runtime — no `_snowflake` module available | Auth via `/snowflake/session/token` file; secrets via env vars (if needed) |
| **EAI** | REST API calls to `{account}.snowflakecomputing.com` may require EAI from container | Must test during build; if needed, add network rule + integration (proven pattern from Cost Monitor) |
| **Deploy** | `snow streamlit deploy --replace` strips EAI on every deploy | CI/CD must re-attach EAI via `snow sql` step (same pattern as Sales Dashboard + Cost Monitor) |
| **Columns** | Gold layer uses UPPER_CASE column names for PBI compatibility | Semantic view must add `synonyms` for user-friendly alternatives ("revenue" → `ROW_TOTAL`) |
| **Warehouse** | `COMPUTE_WH` (XSMALL) shared with Power BI — cannot rename/drop/suspend | Generated SQL executes on this warehouse; monitor for contention via cost dashboard |
| **Semantic View** | Recommended 5-10 tables; 32K token budget for model definition | Phase 1 uses 6 tables — well within limits; expand cautiously in later phases |

---

## Technical Context

> Essential context for Design phase — prevents misplaced files and missed infrastructure needs.

| Aspect | Value | Notes |
|--------|-------|-------|
| **Deployment Location** | `streamlit_analyst/` (new top-level directory) | Separate from `streamlit_app/` and `streamlit_cost_monitor/` |
| **KB Domains** | `snowflake` (Cortex Analyst, Semantic Views), `streamlit` (SiS container runtime) | KB enriched 2026-04-14: 4 new files in `.claude/kb/data-engineering/data-platforms/snowflake/` |
| **IaC Impact** | New Snowflake objects: Semantic View DDL, RBAC grants, possibly EAI + network rule | Bootstrap SQL in `setup/01_bootstrap.sql`; CI/CD workflow in `.github/workflows/` |

### Snowflake Objects to Create

| Object | Name | Owner Role |
|--------|------|-----------|
| Semantic View | `AD_ANALYTICS.GOLD.AMMODEPOT_ANALYST` | `TRANSFORMER_ROLE` |
| Streamlit App | `AD_ANALYTICS.OPS.ANALYST` | `STREAMLIT_ROLE` |
| Network Rule (if needed) | `analyst_api_rule` | `ACCOUNTADMIN` |
| EAI (if needed) | `analyst_api_integration` | `ACCOUNTADMIN` |

### Reusable Patterns from Existing Apps

| Pattern | Source | Reuse in |
|---------|--------|----------|
| Dual-mode auth (SiS + local) | `streamlit_app/utils/db.py` | `streamlit_analyst/utils/db.py` |
| Dark theme constants | `streamlit_app/utils/chart_theme.py` | `streamlit_analyst/utils/chart_theme.py` (subset) |
| CI/CD deploy + EAI re-attach | `.github/workflows/deploy-streamlit-cost-monitor.yml` | `.github/workflows/deploy-streamlit-analyst.yml` |
| `snowflake.yml` v2 definition | `streamlit_app/snowflake.yml` | `streamlit_analyst/snowflake.yml` |

---

## Assumptions

Assumptions that if wrong could invalidate the design:

| ID | Assumption | If Wrong, Impact | Validated? |
|----|------------|------------------|------------|
| A-001 | Cortex Analyst REST API is callable from SiS container runtime without EAI (internal Snowflake API) | Would need network rule + EAI (proven pattern from Cost Monitor, ~1 hour to add) | [ ] Test during build |
| A-002 | `/snowflake/session/token` OAuth token has sufficient privileges to call Cortex Analyst API | Would need alternative auth mechanism; may require `STREAMLIT_ROLE` grants | [ ] Test during build |
| A-003 | `sales_dashboard_pool` has enough headroom for concurrent chatbot + dashboard usage | Would need separate compute pool (~$5/mo extra) or pool scaling | [ ] Monitor during validation |
| A-004 | 6 tables in semantic view stays within 32K token budget | Would need to trim column descriptions or split into multiple views (not supported for cross-view joins) | [ ] Validate during semantic view creation |
| A-005 | `COMPUTE_WH` (XSMALL) handles generated SQL queries without timeout | Would need warehouse scaling or query optimization | [ ] Test with golden questions |
| A-006 | Cortex Analyst correctly handles UPPER_CASE column names from Gold layer | Would need column aliasing in semantic view `expr` fields | [ ] Test during build |
| A-007 | `DASHBOARD_VIEWER_ROLE` has SELECT on all 6 Gold tables referenced in semantic view | Would need additional GRANT statements in bootstrap SQL | [x] Confirmed — existing RBAC grants cover Gold schema |

---

## Semantic View Specification

### Tables (6)

| # | Table | Gold Model | Semantic Role | Dimensions | Facts | Metrics |
|---|-------|-----------|---------------|------------|-------|---------|
| 1 | sales | `F_SALES` | Core fact — revenue, orders, margins | 12 | 7 | 6 |
| 2 | inventory | `F_INVENTORYVIEW` | Inventory snapshot — stock levels, valuation | 1 | 5 | 3 |
| 3 | purchase_orders | `F_POS` | Procurement — POs, lead times, receipts | 4 | 7 | 3 |
| 4 | products | `D_PRODUCT` | Product catalog — SKU, caliber, manufacturer | 11 | 2 | 0 |
| 5 | vendors | `D_VENDOR` | Supplier master — name, lead time, credit | 3 | 3 | 0 |
| 6 | customer_segments | `D_CUSTOMER_SEGMENTATION` | RFM segments — classification, scores | 9 | 4 | 2 |

### Relationships (6)

| # | From | Column | To | Column | Type |
|---|------|--------|----|--------|------|
| 1 | sales | PRODUCT_ID | products | PRODUCT_ID | many-to-one |
| 2 | sales | VENDOR | vendors | vendor_id | many-to-one |
| 3 | sales | RANK_ID | customer_segments | RANK_ID | many-to-one |
| 4 | purchase_orders | vendor_id | vendors | vendor_id | many-to-one |
| 5 | purchase_orders | part_number | products | SKU | many-to-one (explicit) |
| 6 | inventory | part_number | products | SKU | many-to-one (explicit) |

### Verified Queries (10 Golden Questions)

| # | Question | Tables | Pass Criteria |
|---|----------|--------|--------------|
| 1 | "What is total revenue today?" | f_sales | Matches Streamlit Page 1 Net Sales KPI |
| 2 | "What is our gross margin this month?" | f_sales | Matches Page 1 Margin % |
| 3 | "Top 10 products by revenue this week" | f_sales + d_product | Correct SKUs and ordering |
| 4 | "How many units of 9mm are in stock?" | f_inventoryview + d_product | Matches Page 3 inventory filter |
| 5 | "Which vendors have the longest lead times?" | f_pos + d_vendor | Matches Page 3 Vendor Analysis |
| 6 | "Total orders yesterday vs day before" | f_sales | Matches Page 1 delta |
| 7 | "Revenue by category this month" | f_sales + d_product | Matches Page 2 category breakdown |
| 8 | "How many customers are At-Risk Regular?" | d_customer_segmentation | Correct count (no dashboard — manual validation) |
| 9 | "Show me open POs not yet received" | f_pos | Matches Page 3 Open POs tab |
| 10 | "Top 5 manufacturers by units sold MTD" | f_sales + d_product | Matches Page 2 manufacturer chart |

---

## Deliverables

| # | Deliverable | Type | Location |
|---|-------------|------|----------|
| 1 | Semantic View DDL + RBAC grants | SQL | `streamlit_analyst/setup/01_bootstrap.sql` |
| 2 | Verified queries SQL | SQL | `streamlit_analyst/setup/02_verified_queries.sql` |
| 3 | Streamlit app (SiS entry point) | Python | `streamlit_analyst/streamlit_app.py` |
| 4 | Streamlit app (local dev entry point) | Python | `streamlit_analyst/app.py` |
| 5 | Cortex Analyst REST API wrapper | Python | `streamlit_analyst/utils/analyst.py` |
| 6 | Snowpark session + query runner | Python | `streamlit_analyst/utils/db.py` |
| 7 | Dark theme constants | Python | `streamlit_analyst/utils/chart_theme.py` |
| 8 | SiS definition | YAML | `streamlit_analyst/snowflake.yml` |
| 9 | Package dependencies | Text | `streamlit_analyst/requirements.txt` |
| 10 | CI/CD workflow | YAML | `.github/workflows/deploy-streamlit-analyst.yml` |
| 11 | README with Mermaid diagrams | Markdown | `streamlit_analyst/README.md` (already created) |

**Estimated total: ~265 lines of Python + ~150 lines of SQL + ~80 lines of CI/CD YAML**

---

## Cost Estimate

| Component | Monthly Cost | Notes |
|-----------|-------------|-------|
| Cortex Analyst messages | ~$15-50 | 6.7 credits / 100 messages; moderate internal usage |
| COMPUTE_WH SQL execution | Negligible | Shared XSMALL; simple aggregation queries |
| Compute pool | $0 incremental | Shared `sales_dashboard_pool` |
| **Total** | **~$15-50/mo** | Monitor via existing Cost Monitor app |

---

## Clarity Score Breakdown

| Element | Score (0-3) | Notes |
|---------|-------------|-------|
| Problem | 3 | Specific: ops + exec can't answer ad-hoc questions; 3 Gold models have zero dashboard exposure |
| Users | 3 | Two personas with concrete pain points; named user (Seth) for ops |
| Goals | 3 | MoSCoW prioritized; 6 MUST, 3 SHOULD, 2 COULD |
| Success | 3 | 8 quantified criteria with specific thresholds (8/10 accuracy, <5s, <$50/mo) |
| Scope | 3 | 10 YAGNI items explicitly cut; 7 deferred Gold models listed; 5-phase roadmap |
| **Total** | **15/15** | |

---

## Open Questions

None — ready for Design. All questions were resolved during brainstorm:

- Users: Operations + Executive (Q1)
- Golden questions: Derived from existing dashboards (Q2)
- App placement: Separate app, shared pool (Q3)
- Sophistication: Option (a) foundation (Q4)
- Approach: Semantic View + REST API (Approach A)

Two assumptions require validation during build:
- A-001: EAI requirement for Cortex API from container runtime
- A-002: OAuth token privileges for Cortex API

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-14 | define-agent | Initial version from BRAINSTORM_CORTEX_ANALYST_CHATBOT.md |

---

## Next Step

**Ready for:** `/design .claude/sdd/features/DEFINE_CORTEX_ANALYST_CHATBOT.md`
