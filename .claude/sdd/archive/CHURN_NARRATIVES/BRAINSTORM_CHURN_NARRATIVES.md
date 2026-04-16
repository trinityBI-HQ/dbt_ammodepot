# BRAINSTORM: Customer Churn Narratives with CORTEX.COMPLETE

> Exploratory session to clarify intent and approach before requirements capture

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | CHURN_NARRATIVES |
| **Date** | 2026-04-15 |
| **Author** | brainstorm-agent |
| **Status** | Ready for Define |
| **AI Roadmap** | Phase 4 (follows Analyst, Forecasting, Anomaly Detection) |

---

## Initial Idea

**Raw Input:** Phase 4: Customer Churn Narratives with CORTEX.COMPLETE

**Context Gathered:**
- Phases 1-3 of AI roadmap shipped (Cortex Analyst chatbot, FORECAST demand predictions, ANOMALY_DETECTION alerts)
- Rich RFM segmentation already exists in `d_customer_segmentation` with 17 customer classifications
- Cohort models exist (`f_cohort`, `f_cohort_detailed`, `int_customer_cohort`)
- CORTEX.COMPLETE available in Snowflake as SQL function (per-token billing, not warehouse credits)
- Sales Dashboard has 4 pages on SiS container runtime — Page 5 slot available

**Technical Context Observed (for Define):**

| Aspect | Observation | Implication |
|--------|-------------|-------------|
| Likely Location | `streamlit_app/pages/5_Customer_Intelligence.py` | New page in existing Sales Dashboard |
| Data Models | `d_customer_segmentation`, `f_sales`, `d_customer` | All inputs exist — no new dbt models for MVP |
| LLM Function | `SNOWFLAKE.CORTEX.COMPLETE` | SQL-callable, per-token billing, multiple model choices |
| Compute | `sales_dashboard_pool` (shared) | No incremental infra cost |

---

## Discovery Questions & Answers

| # | Question | Answer | Impact |
|---|----------|--------|--------|
| 1 | Primary audience? | Ops/management + dashboard self-serve | Two delivery surfaces but same page works for both |
| 2 | Granularity level? | Segment-level + top-N at-risk customers (recommended by agent) | Balances insight vs. token cost — no per-customer narratives |
| 3 | Generation strategy? | On-demand in Streamlit (option b) | No Snowflake Task needed; `st.cache_data(ttl="10m")` for cost control |
| 4 | Dashboard location? | New Page 5 in Sales Dashboard | Keeps existing 4 pages untouched |
| 5 | Tone/style? | Executive dashboard — numbers-forward, no filler | Matches existing dashboard style; short structured sentences |

---

## Sample Data Inventory

| Type | Location | Count | Notes |
|------|----------|-------|-------|
| Input: RFM segments | `AD_ANALYTICS.GOLD.D_CUSTOMER_SEGMENTATION` | 1 table | 17 classifications, RFM scores, margin, lifetime value |
| Input: Sales | `AD_ANALYTICS.GOLD.F_SALES` | 1 table | Order-level data, incremental merge |
| Input: Customer demographics | `AD_ANALYTICS.GOLD.D_CUSTOMER` | 1 table | Magento customer entity |
| Input: Cohort base | `AD_ANALYTICS.GOLD.INT_CUSTOMER_COHORT` | 1 view | First purchase month per customer |
| Related code | `streamlit_app/pages/1_Today_Yesterday.py` | 1 file | Anomaly alert banner pattern to reuse |
| Related code | `streamlit_app/utils/chart_theme.py` | 1 file | Dark theme + `dark_dataframe()` |
| Output examples | N/A | 0 | No sample narratives — tone described as "executive dashboard" |

**How samples will be used:**
- Segment data feeds the CORTEX.COMPLETE prompt as structured context
- Anomaly alert banner pattern reused for the executive summary rendering
- `dark_dataframe()` reused for segment health and top-N tables

---

## Approaches Explored

### Approach A: Full LLM Narrative per Segment

**Description:** One CORTEX.COMPLETE call per concerning segment (At-Risk, Lost, Inactive, Lapsed). Each gets its own 3-4 sentence narrative block.

**Pros:**
- Rich, per-segment narratives with specific callouts
- Partial failure is OK (one segment fails, others render)
- Granular caching per segment

**Cons:**
- 4-5 LLM calls per page load (~10-15s latency if uncached)
- Higher token cost (~4-5x)
- Narrative quality varies per call — inconsistent tone

---

### Approach B: Single-Prompt Summary

**Description:** One CORTEX.COMPLETE call with ALL segment data packed into the prompt. Returns one cohesive narrative covering all concerning segments.

**Pros:**
- One LLM call (cheapest, fastest ~3-5s)
- Cohesive narrative — LLM can cross-reference segments
- Simple caching

**Cons:**
- One failure kills the whole narrative
- Long prompt may hit quality issues on cheaper models
- Less modular

---

### Approach C: Structured Dashboard + Thin LLM Glue ⭐ Recommended

**Description:** Heavy lifting in SQL — segment KPI cards, top-N tables rendered as normal dashboard elements. CORTEX.COMPLETE generates ONE brief executive summary tying the numbers together.

**Pros:**
- Page works even if LLM fails (structured data renders immediately)
- Cheapest token usage (~100 output tokens per call)
- Fastest perceived load — KPIs appear instantly, narrative fills in
- Consistent with existing dashboard patterns (KPI cards, dark tables)
- Most reliable — 95% of page value is deterministic SQL

**Cons:**
- Less "narrative" per individual segment
- LLM adds less relative value (glue, not main content)

**Why Recommended:** Existing dashboard style is numbers-forward with structured layouts. LLM's highest-value add is connecting dots across segments in one smart paragraph. If CORTEX.COMPLETE has a bad day, the page still works. Estimated cost: ~$0.60/month.

---

## Selected Approach

| Attribute | Value |
|-----------|-------|
| **Chosen** | Approach C — Structured Dashboard + Thin LLM Glue |
| **User Confirmation** | 2026-04-15 |
| **Reasoning** | Matches existing dashboard style, cheapest, most reliable, page degrades gracefully without LLM |

---

## Key Decisions Made

| # | Decision | Rationale | Alternative Rejected |
|---|----------|-----------|----------------------|
| 1 | On-demand generation, not scheduled Task | Data refreshes every 10 min; `st.cache_data(ttl="10m")` matches cadence. Cost negligible (~$0.60/mo) | Pre-computed weekly Task (stale data) |
| 2 | Segment-level + top-N, not per-customer | 90% of insight at 5% of token cost | Per-customer narratives (expensive, slow) |
| 3 | Structured dashboard + thin LLM summary | Page works without LLM; numbers-forward matches existing style | Full LLM narratives per segment (unreliable, expensive) |
| 4 | New Page 5, not embedded in existing pages | Keeps Pages 1-4 untouched; room to expand | Widget on Page 1 or 2 (clutters existing views) |
| 5 | No MoM deltas in MVP | `d_customer_segmentation` has no historical snapshots; requires dbt snapshot first | Simulated prior-month recalculation (complex, expensive) |

---

## Features Removed (YAGNI)

| Feature Suggested | Reason Removed | Can Add Later? |
|-------------------|----------------|----------------|
| Per-customer narrative generation | 5% more insight for 20x token cost | Yes — add as drill-down |
| MoM segment deltas | No historical snapshots exist; needs dbt snapshot of d_customer_segmentation | Yes — add snapshot first |
| Campaign recommendations | Marketing tooling, not ops dashboard | Yes |
| Cohort retention chart | Data exists but separate concern | Yes — natural Page 5 expansion |
| Email/export functionality | No email infra exists; screenshot sufficient | Yes |
| Pre-computed scheduled Task | On-demand chosen; cost negligible | N/A |

---

## Incremental Validations

| Section | Presented | User Feedback | Adjusted? |
|---------|-----------|---------------|-----------|
| Scope summary (audience, granularity, generation, location, tone) | Yes | Confirmed, proceed | No |
| Page 5 layout (summary banner, KPI cards, segment table, top-N table) | Yes | Confirmed, proceed | No |
| YAGNI removals (MoM deltas, per-customer, campaigns) | Yes | Confirmed | No |

---

## Suggested Requirements for /define

### Problem Statement (Draft)
Dashboard users lack a dedicated view of customer health — segment distributions, at-risk customers, and an LLM-generated executive summary that connects the dots across RFM segments.

### Target Users (Draft)
| User | Pain Point |
|------|------------|
| Ops/management | No single view of customer churn risk across segments |
| Dashboard viewers | Must mentally decode RFM codes to understand customer health |

### Success Criteria (Draft)
- [ ] Page 5 renders segment KPI cards and tables without LLM dependency
- [ ] CORTEX.COMPLETE executive summary generates in <5s (cached 10 min)
- [ ] Top 10 at-risk customers displayed by lifetime value
- [ ] All 17 RFM classifications shown with current counts and total value
- [ ] Dark theme consistent with existing pages
- [ ] Works in both local dev and SiS container runtime

### Constraints Identified
- `d_customer_segmentation` has no historical snapshots — MoM deltas deferred
- CORTEX.COMPLETE billed per-token (Cortex LLM credits) — must use caching
- SiS container runtime constraints apply (go.Figure, .tolist(), dark_dataframe())
- Must not modify existing Pages 1-4
- LLM model choice affects cost vs. quality tradeoff (llama3.1-8b cheapest, mistral-large best)

### Out of Scope (Confirmed)
- Per-customer narrative generation
- MoM segment deltas (requires dbt snapshot — separate task)
- Campaign recommendations
- Cohort retention visualization
- Email/export functionality

---

## Technical Notes for Define/Design

### LLM Model Recommendation
`gemini-2-5-flash` — strong structured-to-narrative output, good instruction following at ~$0.15/mo. Cross-region routed (not native us-east-1) but latency irrelevant with 10-min cache. Fallback: `llama3.1-70b` (native us-east-1).

### Prompt Pattern
```sql
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b',
    'You are a data analyst writing for operations managers. ' ||
    'Given this customer segment data, write a 3-4 sentence executive summary. ' ||
    'Be numbers-forward, no filler. Highlight concerning trends. ' ||
    'Data: ' || :segment_json
) AS executive_summary;
```

### Cost Estimate
- ~500 input tokens + ~100 output tokens per call
- `gemini-2-5-flash`: $0.45/M input, $3.75/M output
- `st.cache_data(ttl=600)` → max ~144 calls/day (constant use) → ~$0.02/day
- Realistic: 20-30 calls/day → ~$0.005/day → **~$0.15/month**

### Page Structure (estimated ~400-500 lines)
```
streamlit_app/pages/5_Customer_Intelligence.py
├── SQL: segment_summary query (aggregates from d_customer_segmentation)
├── SQL: top_at_risk query (top-N by LTV in concerning segments)
├── SQL: CORTEX.COMPLETE call (executive summary)
├── Render: Executive summary banner (HTML, dark theme)
├── Render: KPI cards (4 cards, existing pattern)
├── Render: Segment health table (dark_dataframe)
└── Render: Top at-risk table (dark_dataframe)
```

### Fast Follows (post-MVP)
1. **dbt snapshot** of `d_customer_segmentation` → enables MoM deltas
2. **Segment drill-down** → click a segment row to see per-customer details
3. **Cohort retention chart** → Plotly heatmap from `f_cohort`
4. **Cross-filter integration** → link segment clicks to Page 2 filters

---

## Session Summary

| Metric | Value |
|--------|-------|
| Questions Asked | 5 (+1 sub-question) |
| Approaches Explored | 3 |
| Features Removed (YAGNI) | 6 |
| Validations Completed | 2 |

---

## Next Step

**Ready for:** `/define .claude/sdd/features/BRAINSTORM_CHURN_NARRATIVES.md`
