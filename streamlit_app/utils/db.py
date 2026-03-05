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


_TS_HINTS = {"DATE", "TIME", "CREATED", "UPDATED", "BUCKET", "EXTRACTED", "_AT"}


def _convert_timestamp_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Convert string timestamp columns to datetime.

    Snowpark session.sql().to_pandas() can return TIMESTAMP columns as strings
    instead of datetime64. This breaks .dt accessor usage downstream.
    Only converts columns whose name contains a timestamp-related keyword
    to avoid misinterpreting postcodes/IDs as dates.
    """
    for col in df.columns:
        col_upper = col.upper()
        if not any(hint in col_upper for hint in _TS_HINTS):
            continue
        if df[col].dtype == "object" and len(df) > 0:
            sample = df[col].dropna().head(5)
            if len(sample) > 0:
                try:
                    pd.to_datetime(sample)
                    df[col] = pd.to_datetime(df[col], errors="coerce")
                except (ValueError, TypeError):
                    pass
    return df


def _coerce_numeric_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Convert object columns containing Decimal values to native float64.

    Older Snowpark versions return NUMBER(p,s) columns as Python Decimal
    objects stored in object-dtype Series.  pandas groupby().sum() silently
    drops or mis-aggregates object-dtype columns (they are treated as
    non-numeric "nuisance" columns).

    This function ONLY converts columns whose first non-null value is a
    Decimal instance, preserving genuine string columns (POSTCODE, STATUS,
    REGION, etc.) that happen to contain digit-only values.
    """
    from decimal import Decimal as _Decimal

    for col in df.columns:
        if df[col].dtype == "object" and len(df) > 0:
            sample = df[col].dropna().iloc[0] if len(df[col].dropna()) > 0 else None
            if isinstance(sample, _Decimal):
                df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def run_query(sql: str, params: dict | None = None) -> pd.DataFrame:
    """Execute a query and return a pandas DataFrame."""
    if _is_sis:
        df = _session.sql(sql).to_pandas()
        df = _coerce_numeric_columns(df)
        return _convert_timestamp_columns(df)

    conn = get_connection()
    cursor = conn.cursor()
    try:
        if params:
            cursor.execute(sql, params)
        else:
            cursor.execute(sql)
        columns = [desc[0] for desc in cursor.description]
        df = pd.DataFrame(cursor.fetchall(), columns=columns)
        df = _coerce_numeric_columns(df)
        return _convert_timestamp_columns(df)
    finally:
        cursor.close()


def debug_dataframe(df: pd.DataFrame, label: str = "DataFrame") -> None:
    """Show dtype and sample info in an expander. Remove after debugging."""
    import io

    with st.expander(f"DEBUG: {label} ({len(df)} rows)", expanded=False):
        buf = io.StringIO()
        df.info(buf=buf)
        st.text(buf.getvalue())
        if not df.empty:
            st.write("First row raw values + types:")
            row = df.iloc[0]
            debug_rows = []
            for col_name in df.columns:
                val = row[col_name]
                debug_rows.append({
                    "column": col_name,
                    "dtype": str(df[col_name].dtype),
                    "value": repr(val),
                    "type(value)": type(val).__name__,
                })
            st.dataframe(pd.DataFrame(debug_rows))
