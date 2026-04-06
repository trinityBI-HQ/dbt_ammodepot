"""Gold Iceberg Export: Build Gold models from Silver Iceberg + write to Gold Iceberg.

Each model runs in a fresh DuckDB session, loading only its specific Silver
dependencies from Iceberg. This avoids OOM from pre-caching all 76 Silver tables.

Usage:
    python gold_export.py                    # Full export
    python gold_export.py --models d_store   # Specific model
    python gold_export.py --dry-run          # Show plan
"""

import argparse
import glob
import logging
import os
import re
import time

import boto3
import duckdb

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

S3_BUCKET = "ammodepot-lakehouse"
ICEBERG_PREFIX = f"s3://{S3_BUCKET}/iceberg"
GLUE_ACCOUNT_ID = "746669199691"
COMPILED_BASE = "target/compiled/ammodepot_lakehouse/models/gold"

# Execution order: intermediates first, then facts/dims
# Intermediates that depend on other intermediates need ordering
# Execution order respects dependencies:
# Phase 1: Intermediates that DON'T depend on Gold models
# Phase 2: f_sales (core fact, needed by many)
# Phase 3: Intermediates that depend on f_sales
# Phase 4: Remaining Gold models
EXPORT_ORDER = [
    # Phase 1: Independent intermediates
    "int_fishbowl_magento_order_map",
    "int_magento_product_attributes",
    "int_magento_product_eav_lookups",
    "int_magento_product_taxonomy",
    "int_fishbowl_product_enrichment",
    "int_fishbowl_order_cost",
    "int_magento_order_freight",
    "int_magento_product_conversion",
    # Phase 2: Core fact table
    "f_sales",
    # Phase 3: Intermediates that depend on f_sales
    "int_sales_cost_fallback",
    "int_customer_cohort",
    # Phase 4: Remaining Gold
    "d_store",
    "d_vendor",
    "d_customer",
    "d_product_bundle",
    "d_product",
    "f_sales_realtime",
    "f_shippment",
    "f_pos",
    "f_inventoryview",
    "d_customer_segmentation",
    "f_cohort",
    "f_cohort_detailed",
]


def get_deps(compiled_sql: str) -> list[str]:
    """Extract model dependencies from compiled SQL."""
    return list(set(re.findall(r'"memory"\."main"\."([^"]+)"', compiled_sql)))


def init_duckdb() -> duckdb.DuckDBPyConnection:
    con = duckdb.connect(":memory:")
    con.execute("INSTALL httpfs; LOAD httpfs; INSTALL iceberg; LOAD iceberg; INSTALL aws; LOAD aws;")
    con.execute("SET s3_region='us-east-1'")
    con.execute("SET http_timeout=600000")
    con.execute("SET memory_limit='8GB'")
    con.execute("SET temp_directory='/tmp/duckdb_gold_temp'")
    con.execute("CREATE SECRET (TYPE s3, PROVIDER credential_chain)")
    con.execute(f"ATTACH '{GLUE_ACCOUNT_ID}' AS glue (TYPE iceberg, ENDPOINT_TYPE 'GLUE')")
    return con


def load_deps(con: duckdb.DuckDBPyConnection, deps: list[str]) -> None:
    """Load dependencies from Silver or Gold Iceberg into local DuckDB tables."""
    for dep in deps:
        # Check Gold first (for intermediate refs), then Silver
        try:
            con.execute(f'SELECT 1 FROM glue.ammodepot_gold."{dep}" LIMIT 1')
            con.execute(f'CREATE TABLE "{dep}" AS SELECT * FROM glue.ammodepot_gold."{dep}"')
            continue
        except Exception:
            pass

        try:
            con.execute(f'SELECT 1 FROM glue.ammodepot_silver."{dep}" LIMIT 1')
            con.execute(f'CREATE TABLE "{dep}" AS SELECT * FROM glue.ammodepot_silver."{dep}"')
            continue
        except Exception:
            pass

        # Try as seed
        if dep == "customer_groups":
            con.execute("CREATE TABLE customer_groups AS SELECT * FROM read_csv('seeds/customer_groups.csv', auto_detect=true)")
            continue

        log.warning("  Dep %s not found in Gold or Silver Iceberg", dep)


def drop_iceberg(db: str, name: str) -> None:
    glue = boto3.client("glue", region_name="us-east-1")
    s3 = boto3.client("s3", region_name="us-east-1")
    try:
        glue.delete_table(DatabaseName=db, Name=name)
    except Exception:
        pass
    try:
        resp = s3.list_objects_v2(Bucket=S3_BUCKET, Prefix=f"iceberg/{db}.db/{name}/")
        objs = resp.get("Contents", [])
        while objs:
            s3.delete_objects(Bucket=S3_BUCKET, Delete={"Objects": [{"Key": o["Key"]} for o in objs]})
            if resp.get("IsTruncated"):
                resp = s3.list_objects_v2(
                    Bucket=S3_BUCKET, Prefix=f"iceberg/{db}.db/{name}/",
                    ContinuationToken=resp["NextContinuationToken"],
                )
                objs = resp.get("Contents", [])
            else:
                break
    except Exception:
        pass


def export_model(name: str, sql_path: str, dry_run: bool = False) -> str:
    """Export a single Gold model to Iceberg. Returns 'ok:N' or 'error:msg'."""
    with open(sql_path) as f:
        sql = f.read().strip()
    if not sql:
        return "skip:empty"

    deps = get_deps(sql)

    if dry_run:
        log.info("DRY RUN: %s (deps: %s)", name, ", ".join(sorted(deps)))
        return "dry_run"

    log.info("Export: %s (deps: %s)", name, ", ".join(sorted(deps)[:5]))
    t0 = time.time()

    con = init_duckdb()
    try:
        # Skip if already exists in Gold Iceberg
        try:
            cnt = con.execute(f'SELECT count(*) FROM glue.ammodepot_gold."{name}"').fetchone()[0]
            elapsed = time.time() - t0
            log.info("  SKIP: already exists (%s rows, %.1fs)", f"{cnt:,}", elapsed)
            return f"skip:{cnt}"
        except Exception:
            pass

        # Load dependencies
        load_deps(con, deps)

        # Execute the model SQL
        con.execute(f'CREATE TABLE "_result" AS ({sql})')
        cnt = con.execute('SELECT count(*) FROM "_result"').fetchone()[0]

        # Write to Gold Iceberg
        drop_iceberg("ammodepot_gold", name)
        con.execute(f"""
            CREATE TABLE glue.ammodepot_gold.{name}
            WITH ('location' = '{ICEBERG_PREFIX}/ammodepot_gold.db/{name}')
            AS SELECT * FROM "_result"
        """)

        elapsed = time.time() - t0
        log.info("  OK: %s rows in %.1fs", f"{cnt:,}", elapsed)
        return f"ok:{cnt}"
    except Exception as e:
        elapsed = time.time() - t0
        log.error("  FAIL: %s (%.1fs)", str(e)[:300], elapsed)
        return f"error:{e}"
    finally:
        con.close()


def main():
    parser = argparse.ArgumentParser(description="Export Gold models to Iceberg")
    parser.add_argument("--models", help="Comma-separated model names")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    # Compile all models first
    import subprocess
    log.info("Compiling dbt models...")
    subprocess.run(
        ["uv", "run", "dbt", "compile", "--profiles-dir", "."],
        capture_output=True, text=True, timeout=120,
    )

    model_filter = args.models.split(",") if args.models else None

    # Build execution plan
    plan = []
    for name in EXPORT_ORDER:
        if model_filter and name not in model_filter:
            continue
        sql_path = os.path.join(COMPILED_BASE, "intermediate", f"{name}.sql")
        if not os.path.exists(sql_path):
            sql_path = os.path.join(COMPILED_BASE, f"{name}.sql")
        if os.path.exists(sql_path):
            plan.append((name, sql_path))

    log.info("Exporting %d Gold models", len(plan))
    results = {}
    for name, sql_path in plan:
        results[name] = export_model(name, sql_path, dry_run=args.dry_run)

    # Summary
    ok = sum(1 for v in results.values() if v.startswith("ok:"))
    fail = sum(1 for v in results.values() if v.startswith("error:"))
    log.info("Done: %d OK, %d FAIL out of %d", ok, fail, len(results))

    if fail > 0:
        for k, v in results.items():
            if v.startswith("error:"):
                log.error("  %s: %s", k, v[:200])
        raise SystemExit(1)


if __name__ == "__main__":
    main()
