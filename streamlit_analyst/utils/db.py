"""Snowflake connection utility for the Analyst chatbot.

Dual-mode:
  - Streamlit in Snowflake (SiS): uses get_active_session() — no credentials needed
  - Local development: reads credentials from ammodepot/.env with key-pair auth

Same pattern as streamlit_app/utils/db.py, trimmed to essentials.
"""

import pandas as pd
import streamlit as st

_session = None
_is_sis = False

try:
    from snowflake.snowpark.context import get_active_session
    _session = get_active_session()
    _is_sis = True
    _session.sql("USE SCHEMA AD_ANALYTICS.GOLD").collect()
except Exception:
    pass


def _get_local_connection():
    """Local dev: Snowflake connector with key-pair auth from .env."""
    import os
    from pathlib import Path

    from cryptography.hazmat.primitives import serialization
    from dotenv import load_dotenv
    from snowflake.connector import connect

    env_path = Path(__file__).resolve().parents[2] / "ammodepot" / ".env"
    load_dotenv(env_path)

    key_path = Path(__file__).resolve().parents[2] / "ammodepot" / os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]
    passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE", "").encode()
    with open(key_path, "rb") as f:
        pk = serialization.load_pem_private_key(f.read(), password=passphrase or None)
    pk_bytes = pk.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )

    return connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key=pk_bytes,
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database="AD_ANALYTICS",
        schema="GOLD",
        role=os.environ["SNOWFLAKE_ROLE"],
    )


@st.cache_resource
def get_connection():
    """Cached Snowflake connection (local dev only — SiS uses session)."""
    return _get_local_connection()


def get_snowpark_session():
    """Return the active Snowpark session (SiS) or None (local)."""
    return _session


def run_query(sql: str) -> pd.DataFrame:
    """Execute SQL and return a pandas DataFrame."""
    if _is_sis:
        df = _session.sql(sql).to_pandas()
    else:
        conn = get_connection()
        cur = conn.cursor()
        try:
            cur.execute(sql)
            df = pd.DataFrame(cur.fetchall(), columns=[d[0] for d in cur.description])
        finally:
            cur.close()

    # Coerce Decimal → float64 for pandas/plotly compatibility
    from decimal import Decimal
    for col in df.columns:
        if df[col].dtype == "object" and len(df) > 0:
            sample = df[col].dropna().iloc[0] if len(df[col].dropna()) > 0 else None
            if isinstance(sample, Decimal):
                df[col] = pd.to_numeric(df[col], errors="coerce")
    return df
