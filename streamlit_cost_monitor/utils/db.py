"""Snowflake session + cached query runner.

Dual-mode:
  - SiS container runtime: uses ``get_active_session()``.
  - Local dev: uses ``ammodepot/.env`` key-pair auth (reuses the dbt service account).
"""

from __future__ import annotations

import pandas as pd
import streamlit as st

_session = None
_is_sis = False

try:
    from snowflake.snowpark.context import get_active_session

    _session = get_active_session()
    _is_sis = True
except Exception:  # noqa: BLE001 — SnowparkSessionException outside SiS
    pass


def _get_local_session():
    """Local dev — Snowpark session built from dbt service account key."""
    import os
    from pathlib import Path

    from cryptography.hazmat.primitives import serialization
    from dotenv import load_dotenv
    from snowflake.snowpark import Session

    env_path = Path(__file__).resolve().parents[2] / "ammodepot" / ".env"
    load_dotenv(env_path)

    key_path = (
        Path(__file__).resolve().parents[2]
        / "ammodepot"
        / os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]
    )
    passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE", "").encode()
    with open(key_path, "rb") as f:
        private_key = serialization.load_pem_private_key(
            f.read(), password=passphrase or None
        )
    pk_bytes = private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )

    return Session.builder.configs(
        {
            "account": os.environ["SNOWFLAKE_ACCOUNT"],
            "user": os.environ["SNOWFLAKE_USER"],
            "private_key": pk_bytes,
            "warehouse": os.environ["SNOWFLAKE_WAREHOUSE"],
            "database": "SNOWFLAKE",
            "schema": "ACCOUNT_USAGE",
            "role": os.environ["SNOWFLAKE_ROLE"],
        }
    ).create()


@st.cache_resource
def get_session():
    """Return a Snowpark session (SiS active session or local Session)."""
    if _is_sis:
        return _session
    return _get_local_session()


@st.cache_data(ttl="1h", show_spinner=False)
def run_query(sql: str) -> pd.DataFrame:
    """Execute a read-only query and return a pandas DataFrame.

    1-hour cache — account_usage views only refresh every 45 min to 3h
    anyway, so sub-hour polling would waste credits.
    """
    session = get_session()
    df = session.sql(sql).to_pandas()
    # Snowpark returns NUMBER columns as Decimal — coerce to float for pandas/plotly.
    from decimal import Decimal

    for col in df.columns:
        if df[col].dtype == "object" and len(df) > 0:
            sample = df[col].dropna().iloc[0] if df[col].dropna().size > 0 else None
            if isinstance(sample, Decimal):
                df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def is_sis() -> bool:
    return _is_sis
