"""Snowflake connection utility for Streamlit app.

Reads credentials from ammodepot/.env (same as dbt project).
Uses key-pair auth via TRANSFORMER_ROLE for read access to AD_ANALYTICS.GOLD.
"""

import os
from pathlib import Path

import streamlit as st
from cryptography.hazmat.primitives import serialization
from dotenv import load_dotenv
from snowflake.connector import connect

# Load .env from the dbt project
_env_path = Path(__file__).resolve().parents[2] / "ammodepot" / ".env"
load_dotenv(_env_path)


def _get_private_key_bytes() -> bytes:
    key_path = Path(__file__).resolve().parents[2] / "ammodepot" / os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]
    passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE", "").encode()
    with open(key_path, "rb") as f:
        private_key = serialization.load_pem_private_key(f.read(), password=passphrase or None)
    return private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


@st.cache_resource
def get_connection():
    """Cached Snowflake connection (one per app lifecycle)."""
    return connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key=_get_private_key_bytes(),
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database="AD_ANALYTICS",
        schema="GOLD",
        role=os.environ["SNOWFLAKE_ROLE"],
    )


def run_query(sql: str, params: dict | None = None):
    """Execute a query and return a pandas DataFrame."""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        if params:
            cursor.execute(sql, params)
        else:
            cursor.execute(sql)
        columns = [desc[0] for desc in cursor.description]
        import pandas as pd
        return pd.DataFrame(cursor.fetchall(), columns=columns)
    finally:
        cursor.close()
