# streamlit_analyst/ — the Cortex Analyst chatbot

Streamlit in Snowflake app `AD_ANALYTICS.OPS.ANALYST`: natural-language questions answered by
Snowflake Cortex Analyst over the semantic view `AD_ANALYTICS.GOLD.AMMODEPOT_ANALYST`, on the shared
`sales_dashboard_pool`, querying through `COMPUTE_WH`. Cortex was chosen over an external LLM because
the client provides no external API keys (`../docs/decisions/0005-cortex-over-external-llm.md`).
Runtime rules: `../docs/architecture/streamlit-in-snowflake.md`.

- **The semantic view is built from YAML** by `setup/01_bootstrap.sql` via
  `SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML()` — `CREATE SEMANTIC VIEW … AS $$` is invalid, and so are
  `GRANT USAGE ON SEMANTIC VIEW` (grant `SELECT`) and `ALTER … SET VERIFIED_QUERIES` (they go in the
  YAML body).
- **Verified queries are the accuracy lever.** Without them Cortex writes its own SQL: it matched
  `= '9mm'` where `ILIKE '%9mm%'` was needed, and missed that variable cost includes freight.
- **Dimension names must match physical column names.** Quoted mixed-case columns break Cortex's CTE
  aliasing — which is why it reads `int_product_analyst`, an UPPERCASE wrapper over `D_PRODUCT`.
- **Smoke test**: `test_golden_questions.py` runs the golden questions end to end — API and SQL
  execution. Run it after changing the semantic view.
- Authentication: in Snowflake the app reads its OAuth token from `/snowflake/session/token`; locally
  it uses the connector's REST token.
