"""Local development entry point.

Run: streamlit run app.py (from streamlit_analyst/ directory)
SiS entry point is streamlit_app.py (Snowflake convention).
"""

import pandas as pd
import streamlit as st

from utils.analyst import extract_content, send_message
from utils.db import run_query

MAX_DISPLAY_ROWS = 500


def _format_numbers(df: pd.DataFrame) -> pd.DataFrame:
    """Format numeric columns with comma separators and 2 decimal places."""
    df = df.copy()
    for col in df.columns:
        if pd.api.types.is_float_dtype(df[col]):
            df[col] = df[col].map(lambda x: f"{x:,.2f}" if pd.notna(x) else "")
        elif pd.api.types.is_integer_dtype(df[col]):
            df[col] = df[col].map(lambda x: f"{x:,}" if pd.notna(x) else "")
    return df


st.set_page_config(
    page_title="Ammo Depot Sales Assistant",
    page_icon=":material/chat:",
    layout="wide",
)

st.title("Sales Assistant")
st.caption(
    "Ask questions about sales, inventory, products, vendors, and customer segments. "
    "Powered by Snowflake Cortex Analyst."
)

if "messages" not in st.session_state:
    st.session_state.messages = []
if "results" not in st.session_state:
    st.session_state.results = {}

with st.sidebar:
    if st.button("Clear conversation"):
        st.session_state.messages = []
        st.session_state.results = {}
        st.rerun()
    st.divider()
    user_questions = [
        (i, msg["content"][0]["text"])
        for i, msg in enumerate(st.session_state.messages)
        if msg["role"] == "user"
    ]
    if user_questions:
        st.markdown("**Conversation history**")
        for idx, q in user_questions:
            st.caption(f"{(idx // 2) + 1}. {q}")
    else:
        st.caption("No questions yet. Try asking something!")
    st.divider()
    st.caption("Powered by Snowflake Cortex Analyst")

for i, msg in enumerate(st.session_state.messages):
    role = "assistant" if msg["role"] == "analyst" else msg["role"]
    with st.chat_message(role):
        for block in msg["content"]:
            block_type = block.get("type")
            if block_type == "text":
                st.markdown(block["text"])
            elif block_type == "sql":
                with st.expander("Generated SQL", expanded=False):
                    st.code(block["statement"], language="sql")
        if i in st.session_state.results:
            df = st.session_state.results[i]
            st.dataframe(
                _format_numbers(df.head(MAX_DISPLAY_ROWS)),
                use_container_width=True,
            )

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
                            msg_idx = len(st.session_state.messages)
                            st.session_state.results[msg_idx] = df
                            st.dataframe(
                                _format_numbers(df.head(MAX_DISPLAY_ROWS)),
                                use_container_width=True,
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
            except Exception as e:
                st.error(f"Unexpected error: {e}")
