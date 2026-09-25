# streamlit_app/ — the sales dashboard

Streamlit in Snowflake app `AD_ANALYTICS.OPS.SALES_DASHBOARD`: five pages that replace the Power BI
sales, inventory and forecast reports — Today/Yesterday, Sales Overview, Inventory, Forecast, Customer
Intelligence. It runs on `sales_dashboard_pool`, which the analyst chatbot shares. User guide:
`STREAMLIT_USER_GUIDE.md`. Runtime rules shared by all three apps:
`../docs/architecture/streamlit-in-snowflake.md`.

- **Deploy is CI**: `deploy-streamlit-dashboard.yml` on push to `streamlit_app/`, then re-attaches
  `sales_dashboard_integration` (CARTO tiles + PyPI egress) — `--replace` strips it.
- **Matching Power BI is the contract.** Defaults mirror the reports this replaces: Order Status
  preselected to COMPLETE, PROCESSING and UNVERIFIED; Vendor Analysis and Open POs filtered to the
  Ammunition category with `QTY != 0`; dropdown options built from unfiltered data, as Power BI does.
- **Cross-filtering (pages 1–2)**: a chart click stores `(key, value)` in `_ty_xf_pending` /
  `_so_xf_pending`, consumed before the widgets render on the next rerun. Session keys are prefixed
  `ty_xf_` and `so_xf_`.
- **Theme**: every chart goes through `utils/chart_theme.py` — `apply_theme(fig)`, and
  `dark_dataframe(df)` in place of `st.dataframe`.
- Page 4 reads the Task-managed `F_FORECAST` and `F_FORECAST_HISTORY`; page 5 calls
  `SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b')`. Both: `../docs/architecture/ai-features.md`.
