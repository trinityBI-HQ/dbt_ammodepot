"""One-shot parallel-run validation: AD_AIRBYTE vs LAKEHOUSE_LANDING.

Read-only. Runs 4 checks per table across 3 high-volume tables to decide
whether it is safe to disable the Airbyte -> Snowflake connections.
"""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path

import snowflake.connector
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization


@dataclass(frozen=True)
class TablePair:
    label: str
    legacy_db: str
    legacy_schema: str
    legacy_table: str
    iceberg_table: str  # always in AD_ANALYTICS.LAKEHOUSE_LANDING

    @property
    def legacy_fqn(self) -> str:
        return f"{self.legacy_db}.{self.legacy_schema}.{self.legacy_table}"

    @property
    def iceberg_fqn(self) -> str:
        return f"AD_ANALYTICS.LAKEHOUSE_LANDING.{self.iceberg_table}"


TABLES = [
    TablePair("fishbowl.so",         "AD_AIRBYTE", "AD_FISHBOWL", "SO",          "FISHBOWL_SO"),
    TablePair("fishbowl.soitem",     "AD_AIRBYTE", "AD_FISHBOWL", "SOITEM",      "FISHBOWL_SOITEM"),
    TablePair("magento.sales_order", "AD_AIRBYTE", "AD_MAGENTO",  "SALES_ORDER", "MAGENTO_SALES_ORDER"),
]


def _load_env() -> None:
    env_path = Path(__file__).parent.parent / "repos/trinitybi/dbt_ammodepot/ammodepot/.env"
    if not env_path.exists():
        env_path = Path("/home/victoru/repos/trinitybi/dbt_ammodepot/ammodepot/.env")
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip())


def _load_private_key() -> bytes:
    key_path = os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]
    if not os.path.isabs(key_path):
        key_path = str(Path("/home/victoru/repos/trinitybi/dbt_ammodepot/ammodepot") / key_path)
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


def _connect():
    _load_env()
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key=_load_private_key(),
        role="TRANSFORMER_ROLE",
        warehouse="ETL_WH",
    )


def _dedup_cte(fqn: str, pk: str, *, is_iceberg: bool) -> str:
    # _airbyte_extracted_at: TIMESTAMP_TZ in legacy AD_AIRBYTE, NUMBER(ms) in Iceberg.
    # Silver models already use the Iceberg form since Bronze now reads LAKEHOUSE_LANDING.
    extracted_at = (
        "to_timestamp(_airbyte_extracted_at, 3)"
        if is_iceberg
        else "_airbyte_extracted_at"
    )
    return f"""
        select {pk}
        from {fqn}
        where _ab_cdc_deleted_at is null
        qualify row_number() over (
            partition by {pk}
            order by coalesce(
                try_to_timestamp(_ab_cdc_updated_at),
                {extracted_at}
            ) desc nulls last
        ) = 1
    """


def check_counts(cur, t: TablePair, pk: str) -> dict:
    sql = f"""
        with legacy as ({_dedup_cte(t.legacy_fqn, pk, is_iceberg=False)}),
             iceberg as ({_dedup_cte(t.iceberg_fqn, pk, is_iceberg=True)})
        select
            (select count(*) from legacy)  as legacy_rows,
            (select count(*) from iceberg) as iceberg_rows
    """
    cur.execute(sql)
    legacy, iceberg = cur.fetchone()
    diff = (legacy or 0) - (iceberg or 0)
    pct = (abs(diff) / legacy * 100) if legacy else 0.0
    return {
        "legacy_rows": legacy,
        "iceberg_rows": iceberg,
        "row_diff": diff,
        "pct_diff": round(pct, 4),
    }


def check_freshness(cur, t: TablePair) -> dict:
    # _ab_cdc_updated_at is TEXT on both sides — try_to_timestamp is safe.
    sql = f"""
        select
            (select max(try_to_timestamp(_ab_cdc_updated_at)) from {t.legacy_fqn})  as legacy_cdc_max,
            (select max(try_to_timestamp(_ab_cdc_updated_at)) from {t.iceberg_fqn}) as iceberg_cdc_max,
            (select max(_airbyte_extracted_at) from {t.legacy_fqn})                 as legacy_extracted_max,
            (select max(to_timestamp(_airbyte_extracted_at, 3))
             from {t.iceberg_fqn})                                                   as iceberg_extracted_max
    """
    cur.execute(sql)
    legacy_cdc, iceberg_cdc, legacy_ext, iceberg_ext = cur.fetchone()

    def _lag_seconds(a, b):
        if not a or not b:
            return None
        # Both sides must be timezone-aware or naive to subtract cleanly.
        if (a.tzinfo is None) != (b.tzinfo is None):
            a = a.replace(tzinfo=None) if a.tzinfo else a
            b = b.replace(tzinfo=None) if b.tzinfo else b
        return (a - b).total_seconds()

    return {
        "legacy_cdc_max": legacy_cdc.isoformat() if legacy_cdc else None,
        "iceberg_cdc_max": iceberg_cdc.isoformat() if iceberg_cdc else None,
        "cdc_lag_seconds": _lag_seconds(legacy_cdc, iceberg_cdc),
        "legacy_extracted_max": legacy_ext.isoformat() if legacy_ext else None,
        "iceberg_extracted_max": iceberg_ext.isoformat() if iceberg_ext else None,
        "extracted_lag_seconds": _lag_seconds(legacy_ext, iceberg_ext),
    }


def check_tombstones(cur, t: TablePair) -> dict:
    sql = f"""
        select
            (select count(*) from {t.legacy_fqn}  where _ab_cdc_deleted_at is not null) as legacy_tombs,
            (select count(*) from {t.iceberg_fqn} where _ab_cdc_deleted_at is not null) as iceberg_tombs
    """
    cur.execute(sql)
    legacy, iceberg = cur.fetchone()
    return {
        "legacy_tombstones": legacy,
        "iceberg_tombstones": iceberg,
        "tomb_diff": (legacy or 0) - (iceberg or 0),
    }


def check_set_diff(cur, t: TablePair, pk: str) -> dict:
    sql = f"""
        with legacy_ids as ({_dedup_cte(t.legacy_fqn, pk, is_iceberg=False)}),
             iceberg_ids as ({_dedup_cte(t.iceberg_fqn, pk, is_iceberg=True)})
        select
            (select count(*) from legacy_ids  where {pk} not in (select {pk} from iceberg_ids)) as in_legacy_only,
            (select count(*) from iceberg_ids where {pk} not in (select {pk} from legacy_ids))  as in_iceberg_only
    """
    cur.execute(sql)
    legacy_only, iceberg_only = cur.fetchone()
    return {"in_legacy_only": legacy_only, "in_iceberg_only": iceberg_only}


def validate_table(cur, t: TablePair, pk: str) -> dict:
    return {
        "table": t.label,
        "pk": pk,
        "counts": check_counts(cur, t, pk),
        "freshness": check_freshness(cur, t),
        "tombstones": check_tombstones(cur, t),
        "set_diff": check_set_diff(cur, t, pk),
    }


def print_report(results: list[dict]) -> None:
    for r in results:
        print(f"\n{'=' * 72}")
        print(f"  {r['table']}  (pk={r['pk']})")
        print("=" * 72)

        c = r["counts"]
        print(f"  rows  legacy={c['legacy_rows']:>12,}  iceberg={c['iceberg_rows']:>12,}  "
              f"diff={c['row_diff']:>+8,}  ({c['pct_diff']}%)")

        f = r["freshness"]
        cdc_lag = f["cdc_lag_seconds"]
        ext_lag = f["extracted_lag_seconds"]
        cdc_str = f"{cdc_lag:+.0f}s" if cdc_lag is not None else "n/a"
        ext_str = f"{ext_lag:+.0f}s" if ext_lag is not None else "n/a"
        print(f"  cdc   legacy={f['legacy_cdc_max']}")
        print(f"        iceberg={f['iceberg_cdc_max']}  lag={cdc_str}")
        print(f"  ext   legacy={f['legacy_extracted_max']}")
        print(f"        iceberg={f['iceberg_extracted_max']}  lag={ext_str}")

        t = r["tombstones"]
        print(f"  dels  legacy={t['legacy_tombstones']:>12,}  iceberg={t['iceberg_tombstones']:>12,}  "
              f"diff={t['tomb_diff']:>+8,}")

        s = r["set_diff"]
        print(f"  ids   in_legacy_only={s['in_legacy_only']:>8,}  in_iceberg_only={s['in_iceberg_only']:>8,}")


def main() -> int:
    conn = _connect()
    try:
        cur = conn.cursor()
        cur.execute("use role transformer_role")
        cur.execute("use warehouse etl_wh")
        cur.execute("alter session set query_tag = 'validation:lakehouse-parallel-run'")

        results = []
        # Fishbowl tables use id as PK, Magento sales_order uses entity_id
        pk_map = {
            "fishbowl.so":         "id",
            "fishbowl.soitem":     "id",
            "magento.sales_order": "entity_id",
        }
        for table in TABLES:
            print(f"[running] {table.label} ...", flush=True)
            results.append(validate_table(cur, table, pk_map[table.label]))

        print_report(results)
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
