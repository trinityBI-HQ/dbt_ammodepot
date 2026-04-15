# Cortex Analyst + Streamlit Pattern

> **Purpose**: Production pattern for text-to-SQL chatbot in Streamlit on SiS container runtime
> **Confidence**: 0.90
> **MCP Validated**: 2026-04-14

## Overview

Complete implementation pattern for calling Cortex Analyst REST API from a Streamlit app deployed on Snowflake container runtime. Covers authentication, API wrapper, chat UI, SQL execution, and multi-turn conversation.

## Authentication (Container Runtime)

```python
import requests
import os

SNOWFLAKE_ACCOUNT = os.environ.get("SNOWFLAKE_ACCOUNT", "your_account")
SEMANTIC_VIEW = "AD_ANALYTICS.GOLD.AMMODEPOT_ANALYST"
API_URL = f"https://{SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/api/v2/cortex/analyst/message"

def _get_token() -> str:
    """Container runtime: read OAuth token from injected file."""
    try:
        with open("/snowflake/session/token", "r") as f:
            return f.read().strip()
    except FileNotFoundError:
        # Local dev fallback: use snowpark session token
        from snowflake.snowpark.context import get_active_session
        session = get_active_session()
        return session._conn._rest.token

def _headers() -> dict:
    return {
        "Authorization": f"Bearer {_get_token()}",
        "Content-Type": "application/json",
        "X-Snowflake-Authorization-Token-Type": "OAUTH",
    }
```

## API Wrapper

```python
def send_message(messages: list[dict]) -> dict:
    """Call Cortex Analyst with full conversation history."""
    resp = requests.post(
        API_URL,
        headers=_headers(),
        json={"messages": messages, "semantic_view": SEMANTIC_VIEW},
        timeout=90,
    )
    if not resp.ok:
        raise RuntimeError(f"Cortex Analyst error {resp.status_code}: {resp.text}")
    return resp.json()

def extract_content(response: dict) -> tuple[str | None, str | None, list[str]]:
    """Returns (text, sql, suggestions) from analyst response."""
    text, sql, suggestions = None, None, []
    for block in response.get("message", {}).get("content", []):
        if block["type"] == "text":
            text = block["text"]
        elif block["type"] == "sql":
            sql = block["statement"]
        elif block["type"] == "suggestions":
            suggestions = block["suggestions"]
    return text, sql, suggestions
```

## Streamlit Chat UI

```python
import streamlit as st
from snowflake.snowpark.context import get_active_session

st.title("Sales Assistant")

if "messages" not in st.session_state:
    st.session_state.messages = []

# Render conversation history
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        for block in msg["content"]:
            if block["type"] == "text":
                st.markdown(block["text"])
            elif block["type"] == "sql":
                st.code(block["statement"], language="sql")

# Chat input
if prompt := st.chat_input("Ask about sales, inventory, or products..."):
    user_msg = {"role": "user", "content": [{"type": "text", "text": prompt}]}
    st.session_state.messages.append(user_msg)

    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        with st.spinner("Analyzing..."):
            response = send_message(st.session_state.messages)
            text, sql, suggestions = extract_content(response)

            if text:
                st.markdown(text)
            if sql:
                st.code(sql, language="sql")
                # Execute and display results
                session = get_active_session()
                df = session.sql(sql).to_pandas()
                st.dataframe(df.head(500))

            st.session_state.messages.append(response["message"])

# Sidebar: clear conversation
with st.sidebar:
    if st.button("Clear conversation"):
        st.session_state.messages = []
        st.rerun()
```

## SiS Container Runtime Notes

| Concern | Solution |
|---|---|
| Auth token | Auto-injected at `/snowflake/session/token` |
| `_snowflake` module | NOT available in container runtime |
| EAI for Cortex API | Test if internal Snowflake API calls bypass EAI; if not, add network rule for `{account}.snowflakecomputing.com` |
| `--replace` strips EAI | CI/CD must re-attach EAI after every `snow streamlit deploy --replace` |
| Package install | Add `requests` to `requirements.txt`; PyPI egress via EAI |
| SQL execution | Use `get_active_session().sql(...)` — runs on configured warehouse |

## Verified Queries Pattern

Verified queries are the single biggest accuracy lever. Include 10-15 covering common question patterns:

```yaml
verified_queries:
  - name: revenue_today
    question: "What is total revenue today?"
    sql: |
      SELECT SUM(ROW_TOTAL) AS TOTAL_REVENUE
      FROM AD_ANALYTICS.GOLD.F_SALES
      WHERE CREATED_AT::DATE = CURRENT_DATE()
      AND STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
    use_as_onboarding_question: true

  - name: inventory_by_caliber
    question: "How many units of 9mm are in stock?"
    sql: |
      SELECT SUM(i.qty_available) AS UNITS_IN_STOCK
      FROM AD_ANALYTICS.GOLD.F_INVENTORYVIEW i
      JOIN AD_ANALYTICS.GOLD.D_PRODUCT p ON i.part_number = p.SKU
      WHERE p.CALIBER ILIKE '%9mm%'
```

## Error Handling

```python
try:
    response = send_message(st.session_state.messages)
    text, sql, suggestions = extract_content(response)
    if text:
        st.markdown(text)
    if sql:
        df = get_active_session().sql(sql).to_pandas()
        st.dataframe(df.head(500))
except RuntimeError as e:
    st.error(f"Cortex Analyst error: {e}")
except Exception as e:
    st.error(f"Query execution error: {e}")
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Not passing full message history | Include all prior messages for multi-turn context |
| Hardcoding account identifier | Use env var or Snowpark session metadata |
| Displaying raw SQL without execution | Users expect results, not just SQL — always execute |
| No conversation clear button | Long conversations degrade accuracy; provide reset |
| Missing `X-Snowflake-Authorization-Token-Type` header | Required for container runtime OAuth; omitting causes 401 |
| Using `session._conn._rest.token` in production | Only for local dev; container runtime uses file-based token |
