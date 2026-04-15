"""Ammunition Depot Sales Assistant — Streamlit in Snowflake entry point.

Natural language query interface powered by Snowflake Cortex Analyst.
Deployed to AD_ANALYTICS.OPS.ANALYST on container runtime.
"""

import requests.exceptions
import streamlit as st

from utils.analyst import extract_content, send_message
from utils.chart_theme import ACCENT, BG_CHART, BG_INPUT, TEXT_PRIMARY
from utils.db import run_query

MAX_DISPLAY_ROWS = 500

# -- Page config --
try:
    st.set_page_config(
        page_title="Ammo Depot Sales Assistant",
        page_icon=":material/chat:",
        layout="wide",
    )
except Exception:
    pass

# -- Dark theme CSS --
st.markdown(
    f"""<style>
    .stApp {{ background-color: {BG_CHART}; color: {TEXT_PRIMARY}; }}
    [data-testid="stChatMessage"] {{ background-color: {BG_INPUT}; border-radius: 8px; }}
    [data-testid="stChatInput"] textarea {{ color: {TEXT_PRIMARY}; }}
    .stMarkdown a {{ color: {ACCENT}; }}
    </style>""",
    unsafe_allow_html=True,
)

# -- Header --
st.title("Sales Assistant")
st.caption(
    "Ask questions about sales, inventory, products, vendors, and customer segments. "
    "Powered by Snowflake Cortex Analyst."
)

# -- Session state --
if "messages" not in st.session_state:
    st.session_state.messages = []

# -- Render conversation history --
for msg in st.session_state.messages:
    role = "assistant" if msg["role"] == "analyst" else msg["role"]
    with st.chat_message(role):
        for block in msg["content"]:
            block_type = block.get("type")
            if block_type == "text":
                st.markdown(block["text"])
            elif block_type == "sql":
                with st.expander("Generated SQL", expanded=False):
                    st.code(block["statement"], language="sql")

# -- Chat input --
if prompt := st.chat_input("Ask about sales, inventory, or products..."):
    user_msg = {
        "role": "user",
        "content": [{"type": "text", "text": prompt}],
    }
    st.session_state.messages.append(user_msg)

    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        with st.spinner("Analyzing..."):
            try:
                response = send_message(st.session_state.messages)
                text, sql, suggestions = extract_content(response)

                if text:
                    st.markdown(text)

                if sql:
                    with st.expander("Generated SQL", expanded=False):
                        st.code(sql, language="sql")
                    try:
                        df = run_query(sql)
                        if df.empty:
                            st.info("No results found for this query.")
                        else:
                            st.dataframe(
                                df.head(MAX_DISPLAY_ROWS),
                                use_container_width=True,
                            )
                            if len(df) > MAX_DISPLAY_ROWS:
                                st.caption(
                                    f"Showing first {MAX_DISPLAY_ROWS} of "
                                    f"{len(df):,} rows."
                                )
                    except Exception as e:
                        st.error(f"Query execution error: {e}")

                if suggestions:
                    st.markdown("**Try asking:**")
                    for s in suggestions:
                        st.markdown(f"- {s}")

                st.session_state.messages.append(response["message"])

            except RuntimeError as e:
                st.error(f"Error: {e}")
            except requests.exceptions.Timeout:
                st.error(
                    "Request timed out. Try a simpler question."
                )
            except Exception as e:
                st.error(f"Unexpected error: {e}")

# -- Sidebar --
with st.sidebar:
    if st.button("Clear conversation"):
        st.session_state.messages = []
        st.rerun()
    st.divider()
    st.caption("Powered by Snowflake Cortex Analyst")
    st.caption(f"Semantic View: `AMMODEPOT_ANALYST`")
