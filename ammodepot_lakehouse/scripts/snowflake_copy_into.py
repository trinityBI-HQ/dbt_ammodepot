"""Snowflake COPY INTO: Load Gold Iceberg Parquet data from S3 into Snowflake.

Creates a named stage pointing to S3, then COPY INTO each Gold table
from the Iceberg data files (Parquet format).

Usage:
    python snowflake_copy_into.py                      # Full load all Gold tables
    python snowflake_copy_into.py --tables d_store     # Specific table
    python snowflake_copy_into.py --setup              # Create stage only
    python snowflake_copy_into.py --dry-run            # Show SQL
"""

import argparse
import logging
import os
import time

import boto3
import snowflake.connector

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

S3_BUCKET = "ammodepot-lakehouse"
GOLD_PREFIX = "iceberg/ammodepot_gold.db"
STAGE_NAME = "LAKEHOUSE_GOLD_STAGE"
TARGET_SCHEMA = "GOLD"
TARGET_DB = "AD_ANALYTICS"

# Gold tables to load (matches Glue ammodepot_gold tables)
GOLD_TABLES = [
    "d_customer",
    "d_customer_segmentation",
    "d_product",
    "d_product_bundle",
    "d_store",
    "d_vendor",
    "f_cohort",
    "f_cohort_detailed",
    "f_inventoryview",
    "f_sales",
    "f_sales_realtime",
    "f_shippment",
    "int_customer_cohort",
    "int_fishbowl_magento_order_map",
    "int_fishbowl_order_cost",
    "int_fishbowl_product_enrichment",
    "int_magento_order_freight",
    "int_magento_product_attributes",
    "int_magento_product_conversion",
    "int_magento_product_eav_lookups",
    "int_magento_product_taxonomy",
    "int_sales_cost_fallback",
]


def get_snowflake_conn() -> snowflake.connector.SnowflakeConnection:
    """Connect to Snowflake using environment variables."""
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key_file=os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "..", "..", "ammodepot",
            os.environ.get("SNOWFLAKE_PRIVATE_KEY_PATH", "dbt_rsa_key.p8")),
        private_key_file_pwd=os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE", "").encode(),
        database=TARGET_DB,
        warehouse="ETL_WH",
        role="TRANSFORMER_ROLE",
    )


def get_s3_credentials() -> tuple[str, str]:
    """Get S3 credentials for the stage."""
    # Use the svc_airbyte-s3 key (already has access to the bucket)
    # In production, use a storage integration instead
    import subprocess
    result = subprocess.run(
        ["aws", "configure", "export-credentials", "--profile", "ammodepot", "--format", "env-no-export"],
        capture_output=True, text=True,
    )
    key_id = secret = None
    for line in result.stdout.strip().split("\n"):
        k, v = line.split("=", 1)
        if k == "AWS_ACCESS_KEY_ID":
            key_id = v
        elif k == "AWS_SECRET_ACCESS_KEY":
            secret = v
    return key_id, secret


def setup_stage(cur, dry_run: bool = False) -> None:
    """Create the S3 stage for Gold Iceberg data."""
    key_id, secret_key = get_s3_credentials()

    sql = f"""
        USE ROLE TRANSFORMER_ROLE;
        USE DATABASE {TARGET_DB};
        USE SCHEMA {TARGET_SCHEMA};

        CREATE OR REPLACE STAGE {STAGE_NAME}
            URL = 's3://{S3_BUCKET}/{GOLD_PREFIX}/'
            CREDENTIALS = (
                AWS_KEY_ID = '{key_id}'
                AWS_SECRET_KEY = '{secret_key}'
            )
            FILE_FORMAT = (TYPE = PARQUET);
    """

    if dry_run:
        # Mask credentials in dry run
        safe_sql = sql.replace(key_id, "***").replace(secret_key, "***")
        print(safe_sql)
        return

    for stmt in sql.strip().split(";"):
        stmt = stmt.strip()
        if stmt:
            cur.execute(stmt)
    log.info("Stage %s created", STAGE_NAME)


def get_parquet_files(table: str) -> list[str]:
    """List Parquet data files for a Gold Iceberg table in S3."""
    s3 = boto3.client("s3", region_name="us-east-1")
    prefix = f"{GOLD_PREFIX}/{table}/data/"
    resp = s3.list_objects_v2(Bucket=S3_BUCKET, Prefix=prefix)
    files = []
    for obj in resp.get("Contents", []):
        key = obj["Key"]
        if key.endswith(".parquet"):
            # Relative to stage root
            rel = key[len(f"{GOLD_PREFIX}/"):]
            files.append(rel)
    return files


def copy_into_table(cur, table: str, dry_run: bool = False) -> str:
    """COPY INTO a Gold table from Iceberg Parquet files."""
    sf_table = table.upper()
    files = get_parquet_files(table)

    if not files:
        log.warning("  %s: no Parquet files found", table)
        return "skip:no_files"

    # Use MATCH_BY_COLUMN_NAME for flexible column matching
    file_list = ", ".join(f"'{f}'" for f in files)

    sql = f"""
        COPY INTO {TARGET_DB}.{TARGET_SCHEMA}.{sf_table}
        FROM @{TARGET_DB}.{TARGET_SCHEMA}.{STAGE_NAME}
        FILES = ({file_list})
        FILE_FORMAT = (TYPE = PARQUET)
        MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
        PURGE = FALSE;
    """

    if dry_run:
        log.info("DRY RUN: %s (%d files)", table, len(files))
        print(sql)
        return "dry_run"

    t0 = time.time()
    try:
        # Truncate existing data first (full refresh)
        cur.execute(f"TRUNCATE TABLE IF EXISTS {TARGET_DB}.{TARGET_SCHEMA}.{sf_table}")
        cur.execute(sql)
        result = cur.fetchone()
        rows_loaded = result[3] if result else 0  # rows_loaded is 4th column
        elapsed = time.time() - t0
        log.info("  OK: %s rows in %.1fs", f"{rows_loaded:,}", elapsed)
        return f"ok:{rows_loaded}"
    except Exception as e:
        elapsed = time.time() - t0
        log.error("  FAIL: %s (%.1fs)", str(e)[:300], elapsed)
        return f"error:{e}"


def main():
    parser = argparse.ArgumentParser(description="Snowflake COPY INTO from Gold Iceberg")
    parser.add_argument("--tables", help="Comma-separated table names")
    parser.add_argument("--setup", action="store_true", help="Create stage only")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    # Load Snowflake env vars
    env_path = os.path.join(os.path.dirname(__file__), "..", "..", "ammodepot", ".env")
    if os.path.exists(env_path):
        from dotenv import load_dotenv
        load_dotenv(env_path)

    conn = get_snowflake_conn()
    cur = conn.cursor()
    log.info("Connected to Snowflake")

    # Setup stage
    setup_stage(cur, dry_run=args.dry_run)

    if args.setup:
        cur.close()
        conn.close()
        return

    # Determine tables to load
    tables = args.tables.split(",") if args.tables else GOLD_TABLES

    log.info("Loading %d Gold tables", len(tables))
    results = {}
    for table in tables:
        log.info("COPY INTO: %s", table)
        results[table] = copy_into_table(cur, table, dry_run=args.dry_run)

    cur.close()
    conn.close()

    # Summary
    ok = sum(1 for v in results.values() if v.startswith("ok:"))
    fail = sum(1 for v in results.values() if v.startswith("error:"))
    skip = sum(1 for v in results.values() if v.startswith("skip:"))
    log.info("Done: %d OK, %d FAIL, %d SKIP out of %d", ok, fail, skip, len(results))

    if fail > 0:
        for k, v in results.items():
            if v.startswith("error:"):
                log.error("  %s: %s", k, v[:200])
        raise SystemExit(1)


if __name__ == "__main__":
    main()
