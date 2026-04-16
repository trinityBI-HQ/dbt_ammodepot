# BUILD REPORT: Customer Churn Narratives with CORTEX.COMPLETE

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | CHURN_NARRATIVES |
| **Date** | 2026-04-15 |
| **DESIGN** | `.claude/sdd/features/DESIGN_CHURN_NARRATIVES.md` |
| **Status** | Code Complete — Needs Live Validation |

---

## Files Created

| # | File | Action | Lines | Status |
|---|------|--------|-------|--------|
| 1 | `streamlit_app/pages/5_Customer_Intelligence.py` | Created | 403 | Syntax OK, imports verified |

**Files Modified:** None

---

## Implementation Summary

### What Was Built

Page 5 "Customer Intelligence" for the Streamlit Sales Dashboard:

1. **Executive Summary Banner** — `SNOWFLAKE.CORTEX.COMPLETE('gemini-2-5-flash')` generates a 3-4 sentence summary from aggregated segment data. Cached 10 min. Returns `None` on any failure; banner shows "Executive summary unavailable" fallback.

2. **4 KPI Cards** — Total Customers, At-Risk count (with % sub-metric), Lost Buyers (with LTV sub-metric), Healthy Segments % (with LTV sub-metric). Reuses Page 1 HTML/CSS pattern.

3. **Segment Health Table** — All 17 RFM classifications with Customer Count, Total LTV, Avg Days Silent, Avg Purchases. Rendered via `dark_dataframe()` with number formatting.

4. **Segment Distribution Chart** — Horizontal bar chart (Plotly `go.Bar`) color-coded: red for concerning segments, green/accent for positive, grey for neutral. Uses `apply_theme()`.

5. **Top At-Risk Customers Table** — Top 10 highest-LTV customers in 6 concerning segments (At-Risk Regular, Lost Buyer, Inactive, Inactive Regular, Lapsed Buyer, Losing 1-Time Buyer). Shows Customer ID, Segment, LTV, Days Silent, Purchase counts, Group.

### Architecture Decisions Followed

- Single file, no new utils (Decision 1)
- SQL-side aggregation + Python-side prompt assembly (Decision 2)
- Segment categorization as module-level constants (Decision 3)
- LLM model as swappable constant `LLM_MODEL = "gemini-2-5-flash"` (Decision 4)

### Patterns Reused from Existing Pages

| Pattern | Source | Usage |
|---------|--------|-------|
| Logo header + full-width CSS | Pages 1-4 | Identical boilerplate |
| `@st.cache_data(ttl="10m")` | Pages 1-4 | All 3 data loading functions |
| KPI card HTML/CSS | Page 1 | 4 cards, same `.kpi-card` class |
| `dark_dataframe()` with `fmt` | Pages 1-3 | Segment table + at-risk table |
| `apply_theme()` on `go.Figure` | Pages 1-4 | Segment distribution chart |
| `run_query()` dual-mode | All pages | All SQL calls |

---

## Verification

| Check | Result |
|-------|--------|
| Python syntax (`ast.parse`) | Pass |
| Import names exist in utils | Pass (7/7 verified) |
| Logo file exists | Pass (`AmmoDepot.png`, 66KB) |
| Line count | 403 (within 400-500 estimate from DESIGN) |
| No modifications to Pages 1-4 | Pass |
| No modifications to utils/ | Pass |
| No new dependencies needed | Pass |

---

## Live Validation Required

The following cannot be verified without Snowflake credentials:

| Test | AT-ID | How to Validate |
|------|-------|-----------------|
| Page renders with data | AT-001 | `streamlit run app.py` locally with `.env` configured |
| LLM summary generates | AT-002 | Load Page 5, check for summary banner |
| LLM graceful degradation | AT-003 | Temporarily set `LLM_MODEL = "nonexistent"`, reload |
| Cache behavior | AT-004 | Load Page 5, reload within 10 min |
| Empty segment handling | AT-005 | Inspect segment table for all 17 rows |
| SiS runtime | AT-006 | Deploy via `snow streamlit deploy --replace` |
| Local dev | AT-007 | `streamlit run app.py` |
| At-risk filter | AT-008 | Check table shows only concerning segments |

### RBAC Validation (Assumption A-004)

If viewers cannot see the LLM summary, run as ACCOUNTADMIN:

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE POWERBI_READONLY_ROLE;
```

---

## Known Limitations

1. **No MoM deltas** — `D_CUSTOMER_SEGMENTATION` has no historical snapshots. KPI cards show current state only. Fast-follow: add dbt snapshot.
2. **LLM model not validated in region** — `gemini-2-5-flash` is cross-region routed. If unavailable, change `LLM_MODEL` to `"llama3.1-70b"` (one-line fix).
3. **No automated tests** — consistent with Pages 1-4. Page is read-only.

---

## Cost Impact

| Resource | Change | Monthly Cost |
|----------|--------|-------------|
| `sales_dashboard_pool` | No change (shared) | $5/mo (existing) |
| CORTEX.COMPLETE tokens | New (~600 calls/mo) | ~$0.15/mo |
| **Net incremental** | | **~$0.15/mo** |

---

## Next Steps

1. **Validate locally** — `streamlit run app.py`, navigate to Page 5
2. **Validate RBAC** — confirm CORTEX grants for viewer roles
3. **Deploy to SiS** — push to `streamlit_app/` on main (CI auto-deploys)
4. **Ship** — `/ship CHURN_NARRATIVES` after live validation
