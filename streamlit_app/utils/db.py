"""Snowflake connection utility for Streamlit app.

Dual-mode:
  - Streamlit in Snowflake (SiS): uses get_active_session() — no credentials needed
  - Local development: reads credentials from ammodepot/.env with key-pair auth
"""

import pandas as pd
import streamlit as st

# Detect runtime: SiS vs local development
_session = None
_is_sis = False

try:
    from snowflake.snowpark.context import get_active_session
    _session = get_active_session()
    _is_sis = True
except (ImportError, ModuleNotFoundError):
    pass
except Exception:
    # get_active_session() raises SnowparkSessionException outside SiS
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
        private_key = serialization.load_pem_private_key(f.read(), password=passphrase or None)
    private_key_bytes = private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )

    return connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key=private_key_bytes,
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database="AD_ANALYTICS",
        schema="GOLD",
        role=os.environ["SNOWFLAKE_ROLE"],
    )


@st.cache_resource
def get_connection():
    """Cached Snowflake connection (local dev only — SiS uses session)."""
    return _get_local_connection()


def run_query(sql: str, params: dict | None = None) -> pd.DataFrame:
    """Execute a query and return a pandas DataFrame."""
    if _is_sis:
        return _session.sql(sql).to_pandas()

    conn = get_connection()
    cursor = conn.cursor()
    try:
        if params:
            cursor.execute(sql, params)
        else:
            cursor.execute(sql)
        columns = [desc[0] for desc in cursor.description]
        return pd.DataFrame(cursor.fetchall(), columns=columns)
    finally:
        cursor.close()
