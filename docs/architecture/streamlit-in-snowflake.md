---
paths: ["streamlit_app/**", "streamlit_cost_monitor/**", "streamlit_analyst/**", ".github/workflows/deploy-streamlit-*.yml"]
---
# Streamlit in Snowflake — what all three apps share

All three apps run on the **container runtime** (`SYSTEM$ST_CONTAINER_RUNTIME_PY3_11`, Streamlit
1.55+, packages from PyPI through `requirements.txt`, a compute pool per `snowflake.yml`). The
dashboard moved off the warehouse runtime on 2026-04-14; notes written for that runtime no longer
apply.

## Deploying

- **`snow streamlit deploy --replace` is a drop and re-create.** It strips every External Access
  Integration and secret attached with `ALTER STREAMLIT SET`. Each app's CI re-attaches them in a step
  right after the deploy; an app with EAI or secrets and no such step loses PyPI and egress on its
  next push (found 2026-04-09).
- Objects live in `AD_ANALYTICS.OPS`, owned by `STREAMLIT_ROLE`; one-time setup is each app's
  `setup/*.sql`, run as ACCOUNTADMIN.

## Rendering

- **External iframes are blocked** by the runtime's CSP. Open external content in a new tab with
  `st.link_button` — a presigned S3 URL works that way.
- **`st.dataframe` renders in an iframe that ignores page CSS**, and `st.get_option("theme.base")` is
  unreliable. Force dark backgrounds explicitly; the dashboard renders tables as HTML instead.
- **Plotly**: build `go.Figure`/`go.Bar` from plain Python types (`float()`, `.tolist()`) — `px.bar`
  and numpy/pandas values fail to serialize. Use numeric positions with `tickvals`/`ticktext` so
  duplicate categories do not merge. Maps are `go.Scattermap` with CARTO tiles, which need EAI egress
  to `basemaps.cartocdn.com`.
- **Session state**: set defaults in `st.session_state`, render widgets with `key=` only (no
  `value=`). A button that resets widget state uses `on_click=` — assigning widget keys after the
  widget exists raises `StreamlitAPIException`.

## Data

- **`session.sql(...).to_pandas()` returns UPPERCASE column names** (unquoted identifiers fold to
  upper). `row.status` raises; pick one convention per app. The dashboard uses UPPERCASE bracket
  access; the infra monitor lowercases columns in its query helper.
- Each app runs in two modes behind an `_is_sis` flag in its own `utils/db.py`: the active session in
  Snowflake, a key-pair connection locally.
