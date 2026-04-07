"""Parallel refresh of UNMANAGED Iceberg tables in AD_ANALYTICS.LAKEHOUSE_LANDING.

Replaces the dbt on-run-start hook (`refresh_lakehouse_landing` macro), which
issued ALTER REFRESH calls serially via dbt's master connection. dbt cannot
parallelize on-run-start hooks. Running them serially adds 45-90s warm /
3-5min cold to every build, eating into the 10-minute EventBridge window.

This script:
- Discovers all Iceberg tables in LAKEHOUSE_LANDING via SHOW ICEBERG TABLES
- Issues ALTER REFRESH in parallel via a ThreadPoolExecutor (one connection
  per worker thread; snowflake-connector-python connections are not thread-
  safe so we cannot share)
- Fails fast on any error: dbt should not build from a stale catalog
- Logs per-table durations and a final summary that CloudWatch can grep

Called from entrypoint.sh BEFORE `dbt build`. Exit code 0 = safe to proceed,
non-zero = abort the build.
"""

from __future__ import annotations

import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path

import snowflake.connector
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization

# Tunable. ALTER REFRESH is metadata-only (no warehouse compute). The bottleneck
# is Snowflake's metadata service round-trip, not warehouse threads. 8 workers
# gives ~4-6x speedup over serial without hitting per-account API limits.
MAX_WORKERS = 8

LANDING_DATABASE = "AD_ANALYTICS"
LANDING_SCHEMA = "LAKEHOUSE_LANDING"


@dataclass(frozen=True)
class RefreshResult:
    table: str
    seconds: float
    error: str | None = None


def _load_private_key() -> bytes:
    """Read the RSA key from the path the entrypoint.sh writes it to."""
    key_path = os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]
    passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE", "").encode() or None
    with open(key_path, "rb") as fh:
        pkey = serialization.load_pem_private_key(
            fh.read(),
            password=passphrase,
            backend=default_backend(),
        )
    return pkey.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


def _new_connection(pkb: bytes) -> snowflake.connector.SnowflakeConnection:
    """One connection per call. snowflake-connector-python connections are not
    safe to share across threads."""
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key=pkb,
        role=os.environ.get("SNOWFLAKE_ROLE", "TRANSFORMER_ROLE"),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "ETL_WH"),
        session_parameters={"QUERY_TAG": "refresh_iceberg:lakehouse_landing"},
    )


def _discover_tables(pkb: bytes) -> list[str]:
    """Single connection: SHOW ICEBERG TABLES, return name list."""
    conn = _new_connection(pkb)
    try:
        cur = conn.cursor()
        cur.execute(f"show iceberg tables in schema {LANDING_DATABASE}.{LANDING_SCHEMA}")
        rows = cur.fetchall()
        # Column index 1 is 'name' per Snowflake docs.
        return [row[1] for row in rows]
    finally:
        conn.close()


def _refresh_one(pkb: bytes, table: str) -> RefreshResult:
    """Worker: open one connection, run ALTER REFRESH, close. Times the call."""
    start = time.monotonic()
    try:
        conn = _new_connection(pkb)
        try:
            cur = conn.cursor()
            cur.execute(
                f"alter iceberg table {LANDING_DATABASE}.{LANDING_SCHEMA}.{table} refresh"
            )
        finally:
            conn.close()
        return RefreshResult(table=table, seconds=time.monotonic() - start)
    except Exception as exc:
        return RefreshResult(
            table=table,
            seconds=time.monotonic() - start,
            error=str(exc),
        )


def main() -> int:
    pkb = _load_private_key()

    discover_start = time.monotonic()
    tables = _discover_tables(pkb)
    discover_seconds = time.monotonic() - discover_start

    if not tables:
        print("refresh_iceberg: no tables found in LAKEHOUSE_LANDING — nothing to do")
        return 0

    print(
        f"refresh_iceberg: refreshing {len(tables)} iceberg tables "
        f"with {MAX_WORKERS} workers (discovery {discover_seconds:.1f}s)"
    )

    refresh_start = time.monotonic()
    results: list[RefreshResult] = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        futures = {pool.submit(_refresh_one, pkb, t): t for t in tables}
        for future in as_completed(futures):
            results.append(future.result())

    total_seconds = time.monotonic() - refresh_start
    failures = [r for r in results if r.error is not None]
    successes = [r for r in results if r.error is None]

    # Slowest 3 successful refreshes — useful for spotting cold-cache outliers.
    successes.sort(key=lambda r: r.seconds, reverse=True)
    slowest_lines = [f"{r.table} ({r.seconds:.1f}s)" for r in successes[:3]]

    print(
        f"refresh_iceberg: refreshed {len(successes)}/{len(tables)} in "
        f"{total_seconds:.1f}s (slowest: {', '.join(slowest_lines)})"
    )

    if failures:
        print("refresh_iceberg: FAIL — the following tables errored:")
        for r in failures:
            print(f"  - {r.table}: {r.error}")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
