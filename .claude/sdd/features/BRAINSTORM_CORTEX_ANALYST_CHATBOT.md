# BRAINSTORM: Cortex Analyst Text-to-SQL Chatbot

> Exploratory session to clarify intent and approach before requirements capture

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | CORTEX_ANALYST_CHATBOT |
| **Date** | 2026-04-14 |
| **Author** | brainstorm-agent |
| **Status** | Ready for Define |

---

## Initial Idea

**Raw Input:** Build a natural language query interface (chatbot) for the Ammunition Depot analytics pipeline. Embed it as a separate Streamlit SiS app that uses Snowflake Cortex Analyst to translate user questions into SQL against the Gold layer. Phase 1 of a 5-phase AI feature rollout.

**Context Gathered:**
- Gold layer is mature: 13 models (6 fact + 7 dimension), well-documented YAML schemas with column descriptions and tests
- Existing Streamlit Sales Dashboard (3 pages, ~4,790 lines) deployed on SiS container runtime — proven deployment pattern
- Existing Cost Monitor app (4 pages) — proven EAI + secrets + CI/CD pattern
- Client constraint: no external LLM API keys will be provided — all AI must stay within Snowflake compute billing
- Primary users: Operations team (inventory, orders, shipping) + Executive/ownership (revenue, margins, trends)
- KB gap: Cortex Analyst, Cortex ML functions, Cortex Search not documented in `.claude/kb/`

**Technical Context Observed (for Define):**

| Aspect | Observation | Implication |
|--------|-------------|-------------|
| Likely Location | `streamlit_analyst/` (new top-level dir) | Separate app, same compute pool as sales dashboard |
| Relevant KB Domains | snowflake (Cortex Analyst, Semantic Views), streamlit (SiS container runtime) | Need KB enrichment before build phase |
| IaC Patterns | GitHub Actions CI/CD (proven for 2 existing Streamlit apps) | Reuse `deploy-streamlit-*.yml` pattern |

---

## Discovery Questions & Answers

| # | Question | Answer | Impact |
|---|----------|--------|--------|
| 1 | Who are the primary users of this chatbot? | Operations team (Seth + warehouse) + Executive/ownership | Semantic model must cover both precise lookups (inventory, POs) and trend aggregations (revenue, margins) |
| 2 | Top questions users ask that dashboards can't answer? | Derived from existing BI: 10 golden questions spanning stock-out prediction, margin by segment, vendor lead times, use-type revenue, overdue POs | These become the verified query set and validation test suite |
| 3 | New page in Sales Dashboard or separate app? | Separate Streamlit app, same compute pool (`sales_dashboard_pool`) | Independent deploy cycle, no risk to production dashboard, $0 incremental compute |
| 4 | What level of answer sophistication? | Option (a): Simple lookups and aggregations across 6 Gold models. Cross-model joins deferred to Phase 2 | Semantic view stays under 6 tables, verified queries focus on single-table aggregations with 1-hop joins to dimensions |

---

## Sample Data Inventory

> Samples improve LLM accuracy through in-context learning and few-shot prompting.

| Type | Location | Count | Notes |
|------|----------|-------|-------|
| Column descriptions | `ammodepot/models/gold/*.yml` | 14 YAML files | Direct mapping to semantic view dimensions/facts |
| Proven SQL queries | `streamlit_app/pages/*.py` | 6 SQL strings | `load_sales()`, `load_inventory()`, `load_pos_data()` etc. — become verified queries |
| Ground truth KPIs | Streamlit dashboard (live) | 15+ KPI cards | Validation: chatbot answers must match dashboard numbers |
| Related code | `streamlit_app/utils/db.py` | 1 file | Reusable Snowpark session + query runner pattern |

**How samples will be used:**

- Gold YAML descriptions → semantic view column descriptions and synonyms
- Streamlit SQL queries → verified queries (pre-validated SQL for golden questions)
- Dashboard KPI values → validation test suite (chatbot answer == dashboard number)
- `utils/db.py` pattern → reuse for executing generated SQL in the new app

---

## Approaches Explored

### Approach A: Semantic View + REST API (Recommended)

**Description:** Create a `SEMANTIC VIEW` in `AD_ANALYTICS.GOLD` covering 6 Gold models. Call Cortex Analyst REST API from a new Streamlit SiS app. Auth via `/snowflake/session/token` (container runtime OAuth). Verified queries for top 10-15 golden questions.

**Pros:**
- Native Snowflake RBAC — `TRANSFORMER_ROLE` owns, `DASHBOARD_VIEWER_ROLE` gets USAGE
- Snowsight wizard for creation and maintenance (client handoff friendly)
- Relationship types auto-inferred between tables
- Verified queries ensure accurate answers for golden questions
- No stage management, no YAML files to sync

**Cons:**
- Semantic view DDL not naturally Git-tracked (requires `GET_DDL()` extraction)
- May need EAI for REST API calls from container runtime (needs testing)
- Less portable if client ever moves off Snowflake

**Why Recommended:** Native RBAC + auto-inferred relationships + Snowsight wizard = lowest maintenance burden for the client after handoff. Git tracking gap is solvable with DDL extraction in CI/CD.

---

### Approach B: YAML on Stage + REST API

**Description:** Same REST API pattern, but semantic model lives as YAML file on a Snowflake stage. YAML lives in Git and deploys via CI/CD (`snow stage copy`).

**Pros:**
- YAML lives in Git alongside dbt project — full version control
- CI/CD deploys semantic model changes alongside Streamlit code
- Easier to review in PRs (diff-able YAML)

**Cons:**
- Stage-level permissions only (no granular RBAC)
- Must manually define `relationship_type` (no auto-inference)
- Snowflake documentation calls this "legacy" — semantic views recommended
- No Snowsight wizard for editing

---

### Approach C: Cortex Agents API

**Description:** Cortex Agents wraps Analyst + Search + custom tools into a single orchestration layer.

**Pros:**
- Single API for text-to-SQL + RAG + tool execution
- Natural upgrade path for Phase 2-5 features

**Cons:**
- Newer feature, less battle-tested
- More complex to configure and debug
- Overkill for Phase 1 (simple lookups and aggregations)

---

## Selected Approach

| Attribute | Value |
|-----------|-------|
| **Chosen** | Approach A (Semantic View + REST API) |
| **User Confirmation** | 2026-04-14 |
| **Reasoning** | Native RBAC integration with existing 6-role setup, auto-inferred relationships reduce manual config, Snowsight wizard enables client self-service maintenance. Git tracking gap is an acceptable trade-off. |

---

## Key Decisions Made

| # | Decision | Rationale | Alternative Rejected |
|---|----------|-----------|----------------------|
| 1 | No external LLM APIs — Cortex Analyst only | Client will not provide API keys; all AI stays within Snowflake compute billing | Claude API (Option 2), Hybrid Cortex+Claude (Option 3) |
| 2 | Separate Streamlit app, shared compute pool | Independent deploy cycle without risking production dashboard; $0 incremental compute | New page in existing Sales Dashboard (would add risk to 4,790-line app) |
| 3 | Semantic View over YAML on stage | Native RBAC, auto-inferred relationships, Snowsight wizard for maintenance | YAML on stage (legacy, no RBAC, manual relationships) |
| 4 | Option (a) — simple lookups + aggregations for Phase 1 | Debuggable, reliable, fast to ship; cross-model joins deferred to Phase 2 | Option (b) with 4 cross-model queries (higher risk, harder to validate) |
| 5 | 6 Gold models in semantic view (not all 13) | f_sales, f_inventoryview, f_pos, d_product, d_vendor, d_customer_segmentation cover ops + exec questions | f_cohort, f_cohort_detailed, f_shippment, d_store, d_customer, d_product_bundle, f_sales_realtime deferred |
| 6 | COMPUTE_WH for SQL execution | Already granted to BI roles, shared with Power BI, XSMALL sufficient for aggregation queries | New dedicated warehouse (unnecessary cost for simple queries) |

---

## Features Removed (YAGNI)

| Feature Suggested | Reason Removed | Can Add Later? |
|-------------------|----------------|----------------|
| Cross-model joins (stock-out prediction, margin by segment) | Phase 2 — foundation must be proven reliable first | Yes (Phase 2) |
| Cortex `COMPLETE()` for narrative summaries | Phase 4 per roadmap — overkill for simple lookups | Yes (Phase 4) |
| Cortex Search (vector RAG over metadata) | No unstructured documents to search; Gold tables are structured | Maybe |
| Multi-turn persistent memory (across sessions) | Session state sufficient; users ask fresh questions each visit | Maybe |
| Chart/visualization generation from answers | Users already have Streamlit dashboards for visuals; chatbot returns tables | Yes (Phase 3) |
| Streaming responses | Questions return in 2-5s; streaming adds complexity for marginal UX gain | Maybe |
| Separate compute pool | Shared `sales_dashboard_pool` has headroom; revisit if contention | If needed |
| FORECAST function | Phase 2 per roadmap — demand forecasting is a separate feature | Yes (Phase 2) |
| ANOMALY_DETECTION function | Phase 3 per roadmap — anomaly alerts are a separate feature | Yes (Phase 3) |
| Product affinity engine | Phase 5 per roadmap — requires SQL co-occurrence analysis | Yes (Phase 5) |

---

## Incremental Validations

| Section | Presented | User Feedback | Adjusted? |
|---------|-----------|---------------|-----------|
| Architecture concept (data flow, RBAC, file structure, cost estimate) | Yes | "looks right" | No |
| Component breakdown (semantic view columns, verified queries, Streamlit files, CI/CD, validation plan) | Yes | "yes, look right" | No |

---

## Suggested Requirements for /define

Based on this brainstorm session, the following should be captured in the DEFINE phase:

### Problem Statement (Draft)

Operations and executive users at Ammunition Depot cannot answer ad-hoc analytical questions without requesting custom queries from the data team. The existing Streamlit dashboards cover structured KPIs but cannot handle freeform questions like "How many customers are At-Risk Regular?" or "Which vendors have the longest lead times?" A natural language chatbot powered by Snowflake Cortex Analyst would enable self-service querying against the Gold layer without external API dependencies.

### Target Users (Draft)

| User | Pain Point |
|------|------------|
| Operations team (Seth + warehouse) | Cannot quickly answer inventory/PO/vendor questions without manual SQL or waiting for data team |
| Executive/ownership | Cannot get ad-hoc margin, segment, or trend answers without pre-built dashboard views |

### Success Criteria (Draft)

- [ ] 8/10 golden questions return correct SQL and matching results on first attempt
- [ ] Out-of-scope questions are gracefully refused (no hallucinated SQL)
- [ ] SQL injection attempts are blocked
- [ ] Median response time < 5 seconds end-to-end
- [ ] RBAC: `DASHBOARD_VIEWER_ROLE` can use chatbot but cannot access Silver/Bronze
- [ ] Deployed to SiS container runtime with CI/CD (GitHub Actions)
- [ ] Cortex Analyst credit consumption < $50/month at moderate usage

### Constraints Identified

- No external LLM API keys — all AI within Snowflake compute
- Shared `sales_dashboard_pool` (CPU_X64_XS, 1 node) — chatbot must not starve the sales dashboard
- Container runtime: auth via `/snowflake/session/token`, no `_snowflake` module
- EAI may be needed for REST API calls to `{account}.snowflakecomputing.com` — requires testing
- `--replace` strips EAI on every deploy — CI must re-attach (proven pattern)
- UPPER_CASE Gold column names (PBI compatibility) — semantic view must map these to user-friendly synonyms

### Out of Scope (Confirmed)

- Cross-model calculated metrics (stock-out prediction, margin by customer segment) — Phase 2
- Cortex ML functions (FORECAST, ANOMALY_DETECTION) — Phases 2-3
- Cortex COMPLETE() for narrative summaries — Phase 4
- Chart generation from chatbot answers — Phase 3
- Product affinity / "frequently bought together" — Phase 5
- Persistent conversation history across sessions
- Streaming responses
- Export functionality beyond built-in `st.dataframe` download

### Phase Roadmap (Confirmed)

| Phase | Feature | Cortex Function | Effort |
|-------|---------|----------------|--------|
| **1 (this)** | Text-to-SQL Chatbot | Cortex Analyst + Semantic View | 3-4 days |
| 2 | Demand Forecasting | `SNOWFLAKE.ML.FORECAST` | 2-3 days |
| 3 | Sales/Cost Anomaly Alerts | `SNOWFLAKE.ML.ANOMALY_DETECTION` | 1-2 days |
| 4 | Customer Churn Narrative | `CORTEX.COMPLETE()` + segmentation | 2-3 days |
| 5 | Product Affinity Engine | SQL + `CORTEX.COMPLETE()` | 2-3 days |

---

## Semantic View: Table Coverage (Phase 1)

### f_sales — Sales Fact

| Section | Columns |
|---------|---------|
| **Dimensions** | STATUS, STOREFRONT, STORE_NAME, CUSTOMER_EMAIL, CUSTOMER_NAME, REGION, CITY, POSTCODE, PRODUCT_ID, ORDER_ID, INCREMENT_ID, VENDOR |
| **Time Dimensions** | CREATED_AT |
| **Facts** | ROW_TOTAL, COST, QTY_ORDERED, FREIGHT_REVENUE, FREIGHT_COST, TAX_AMOUNT, PART_QTY_SOLD |
| **Metrics** | total_revenue `SUM(ROW_TOTAL)`, total_orders `COUNT(DISTINCT ORDER_ID)`, gross_margin `(SUM(ROW_TOTAL) - SUM(COST)) / NULLIF(SUM(ROW_TOTAL), 0)`, aov `SUM(ROW_TOTAL) / NULLIF(COUNT(DISTINCT ORDER_ID), 0)`, total_gp `SUM(ROW_TOTAL) - SUM(COST)`, total_units `SUM(QTY_ORDERED)` |
| **Filters** | completed_orders `STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')`, this_month, this_year |

### f_inventoryview — Inventory Snapshot

| Section | Columns |
|---------|---------|
| **Dimensions** | part_number |
| **Facts** | qty_available, qty_not_available, qty_on_order, part_cost, extended_cost |
| **Metrics** | total_on_hand `SUM(qty_available)`, total_cost_on_hand `SUM(extended_cost)`, total_on_order `SUM(qty_on_order)` |

### f_pos — Purchase Orders

| Section | Columns |
|---------|---------|
| **Dimensions** | part_number, vendor_id, purchase_order_id, receipt_item_status_id |
| **Time Dimensions** | po_created_at, datereceived |
| **Facts** | qty, unit_cost, total_cost, vendor_lead_time, precise_leadtime, quantity_fulfilled, quantity_to_fulfill |
| **Metrics** | avg_lead_time `AVG(precise_leadtime)`, total_po_cost `SUM(total_cost)`, total_qty_received `SUM(qty)` |
| **Filters** | received_only `receipt_item_status_id = 2`, reconciled_only `receipt_item_status_id = 4` |

### d_product — Product Dimension

| Section | Columns |
|---------|---------|
| **Dimensions** | SKU, PRODUCT_NAME (synonyms: "product", "item"), CALIBER, MANUFACTURER (synonyms: "brand", "maker"), PROJECTILE, VENDOR (synonyms: "fulfilled by", "supplier"), USE_TYPE_CATEGORY (synonyms: "use type", "product type"), PRIMARY_CATEGORY (synonyms: "category"), DISCONTINUED, UNIT_TYPE, ROUNDS_PER_PACKAGE |
| **Facts** | AVGCOST, LASTVENDORCOST |

### d_vendor — Vendor Dimension

| Section | Columns |
|---------|---------|
| **Dimensions** | vendor_id, vendor_name (synonyms: "vendor", "supplier"), is_active |
| **Facts** | lead_time_days, credit_limit, minimum_order_amount |
| **Filters** | active_vendors `is_active = TRUE` |

### d_customer_segmentation — Customer Segments

| Section | Columns |
|---------|---------|
| **Dimensions** | CUSTOMER_EMAIL, RANK_ID, FREQUENCY (F0-F5), RECENCY (R0-R5), VALUE (V0-V5), MARGIN (M0-M5), MONETARY_VALUE (MV0-MV5), CUSTOMER_CLASSIFICATION (synonyms: "segment", "customer type"), CUSTOMER_GROUP (synonyms: "group", "account type") |
| **Facts** | TOTAL_REVENUE, NUMBER_OF_PURCHASES, DAYS_SINCE_LAST_PURCHASE, TOTAL_PURCHASES_ALL_TIME |
| **Metrics** | avg_revenue `AVG(TOTAL_REVENUE)`, customer_count `COUNT(DISTINCT RANK_ID)` |

### Relationships

| Left Table | Left Column | Right Table | Right Column | Type |
|---|---|---|---|---|
| f_sales | PRODUCT_ID | d_product | PRODUCT_ID | many-to-one |
| f_sales | VENDOR | d_vendor | vendor_id | many-to-one |
| f_sales | RANK_ID | d_customer_segmentation | RANK_ID | many-to-one |
| f_pos | vendor_id | d_vendor | vendor_id | many-to-one |
| f_pos | part_number | d_product | SKU | many-to-one (explicit) |
| f_inventoryview | part_number | d_product | SKU | many-to-one (explicit) |

---

## Golden Question Validation Set

| # | Question | Expected Source | Expected SQL Pattern |
|---|----------|----------------|---------------------|
| 1 | "What is total revenue today?" | f_sales | `SUM(ROW_TOTAL) WHERE CREATED_AT = CURRENT_DATE()` |
| 2 | "What is our gross margin this month?" | f_sales | `(SUM(ROW_TOTAL) - SUM(COST)) / SUM(ROW_TOTAL) WHERE month = current` |
| 3 | "Top 10 products by revenue this week" | f_sales + d_product | `GROUP BY product, ORDER BY SUM DESC LIMIT 10` |
| 4 | "How many units of 9mm are in stock?" | f_inventoryview + d_product | `SUM(qty_available) WHERE CALIBER LIKE '%9mm%'` |
| 5 | "Which vendors have the longest lead times?" | f_pos + d_vendor | `GROUP BY vendor_name ORDER BY AVG(precise_leadtime) DESC` |
| 6 | "Total orders yesterday vs day before" | f_sales | Two `COUNT(DISTINCT ORDER_ID)` with date filters |
| 7 | "Revenue by category this month" | f_sales + d_product | `GROUP BY PRIMARY_CATEGORY, SUM(ROW_TOTAL)` |
| 8 | "How many customers are At-Risk Regular?" | d_customer_segmentation | `COUNT WHERE CUSTOMER_CLASSIFICATION = 'At-Risk Regular'` |
| 9 | "Show me open POs not yet received" | f_pos | `WHERE datereceived IS NULL AND quantity_to_fulfill > 0` |
| 10 | "Top 5 manufacturers by units sold MTD" | f_sales + d_product | `GROUP BY MANUFACTURER, SUM(QTY_ORDERED) LIMIT 5` |

---

## Session Summary

| Metric | Value |
|--------|-------|
| Questions Asked | 4 (users, top questions, app placement, sophistication level) |
| Approaches Explored | 3 (Semantic View, YAML on Stage, Cortex Agents) |
| Features Removed (YAGNI) | 10 (cross-model joins, FORECAST, ANOMALY_DETECTION, COMPLETE, Search, streaming, charts, memory, export, separate pool) |
| Validations Completed | 2 (architecture concept, component breakdown) |
| Duration | ~45 min |

---

## Next Step

**Ready for:** `/define .claude/sdd/features/BRAINSTORM_CORTEX_ANALYST_CHATBOT.md`
