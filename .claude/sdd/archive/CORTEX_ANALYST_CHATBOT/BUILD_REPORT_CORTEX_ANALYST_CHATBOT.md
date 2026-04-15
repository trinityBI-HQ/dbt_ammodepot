# BUILD REPORT: Cortex Analyst Text-to-SQL Chatbot

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | CORTEX_ANALYST_CHATBOT |
| **Date** | 2026-04-14 |
| **DESIGN** | [DESIGN_CORTEX_ANALYST_CHATBOT.md](../features/DESIGN_CORTEX_ANALYST_CHATBOT.md) |
| **Status** | Build Complete — Pending Deployment |

---

## Files Created

| # | File | Lines | Status | Verification |
|---|------|-------|--------|-------------|
| 1 | `streamlit_analyst/utils/__init__.py` | 0 | Created | N/A (empty init) |
| 2 | `streamlit_analyst/utils/chart_theme.py` | 11 | Created | AST parse OK |
| 3 | `streamlit_analyst/utils/db.py` | 89 | Created | AST parse OK |
| 4 | `streamlit_analyst/utils/analyst.py` | 90 | Created | AST parse OK |
| 5 | `streamlit_analyst/streamlit_app.py` | 123 | Created | AST parse OK |
| 6 | `streamlit_analyst/app.py` | 100 | Created | AST parse OK |
| 7 | `streamlit_analyst/snowflake.yml` | 19 | Created | YAML valid |
| 8 | `streamlit_analyst/requirements.txt` | 4 | Created | N/A |
| 9 | `streamlit_analyst/setup/01_bootstrap.sql` | 537 | Created | Includes full semantic view DDL |
| 10 | `streamlit_analyst/setup/02_verified_queries.sql` | 157 | Created | 10 golden questions |
| 11 | `.github/workflows/deploy-streamlit-analyst.yml` | 96 | Created | Same pattern as cost monitor |
| 12 | `streamlit_analyst/README.md` | (pre-existing) | Created in brainstorm phase | 4 Mermaid diagrams |

**Total: 1,203 lines across 12 files**

---

## Verification Results

| Check | Result | Notes |
|-------|--------|-------|
| Python AST parse (5 files) | PASS | All 5 Python files parse without syntax errors |
| File manifest complete | PASS | All 11 files from DESIGN manifest created |
| Patterns followed | PASS | Code matches DESIGN code patterns 1-6 |
| No hardcoded secrets | PASS | All credentials via env vars / token file |
| No TODO comments | PASS | No outstanding TODOs in source code |

---

## Assumptions to Validate During Deployment

| ID | Assumption | How to Validate |
|----|------------|-----------------|
| A-001 | Cortex Analyst API callable from container runtime without EAI | Deploy app, ask a question. If 403/network error → add EAI network rule |
| A-002 | `/snowflake/session/token` has Cortex Analyst privileges | Deploy app, ask a question. If 401 → check STREAMLIT_ROLE grants |
| A-004 | Semantic view YAML stays within 32K token budget | Run `CREATE SEMANTIC VIEW` — if error → trim descriptions/synonyms |
| A-006 | Cortex Analyst handles UPPER_CASE + quoted column names | Test golden questions after semantic view creation |

---

## Deployment Steps (Manual — Pre-CI/CD)

### Step 1: Create Semantic View (run once as ACCOUNTADMIN)

```sql
-- Copy-paste from streamlit_analyst/setup/01_bootstrap.sql
-- Run in Snowsight or snow sql
```

### Step 2: Add Verified Queries

```sql
-- Copy-paste from streamlit_analyst/setup/02_verified_queries.sql
-- Run after Step 1
```

### Step 3: Deploy Streamlit App

```bash
cd streamlit_analyst
snow streamlit deploy --replace --connection deploy
```

### Step 4: Test

Ask the 10 golden questions and compare to dashboard values.

---

## Known Gaps

| Gap | Severity | Resolution |
|-----|----------|------------|
| EAI may be needed for Cortex API from container | Low (proven fix pattern) | Add network rule + EAI in bootstrap if testing confirms |
| `requests.exceptions.Timeout` import at module level in streamlit_app.py | Cosmetic | `requests` is installed via requirements.txt; import works |
| D_PRODUCT quoted column names (`"Product ID"`, `"Product Name"`) | Medium | Must test that semantic view DDL handles Snowflake's case-sensitive identifiers correctly |

---

## Build Summary

| Metric | Value |
|--------|-------|
| Files created | 12 (11 manifest + 1 pre-existing README) |
| Total lines | 1,203 |
| Python files | 5 (413 lines) |
| SQL files | 2 (694 lines) |
| Config/CI files | 4 (96 lines) |
| Verification checks | 5/5 PASS |
| Blockers | 0 |
| Assumptions pending | 4 (validate during deployment) |

---

## Next Step

**Ready for deployment + validation, then:** `/ship CORTEX_ANALYST_CHATBOT`
