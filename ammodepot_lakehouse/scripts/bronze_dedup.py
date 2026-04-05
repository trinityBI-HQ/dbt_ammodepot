"""Bronze Dedup: Landing (append-only Iceberg) → Bronze (clean Iceberg).

Reads CDC append-only tables written by Airbyte, deduplicates by primary key
(keeping latest _ab_cdc_updated_at), filters out CDC deletes, and writes
clean Iceberg tables to the ammodepot_bronze Glue database.

Usage:
    python bronze_dedup.py                    # Full refresh all 55 tables
    python bronze_dedup.py --tables so,soitem # Specific tables only
    python bronze_dedup.py --source fishbowl  # One source only
    python bronze_dedup.py --dry-run          # Show SQL without executing
"""

import argparse
import logging
import time
from dataclasses import dataclass

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


@dataclass
class TableConfig:
    """Landing-to-Bronze table mapping."""

    landing_db: str       # Glue database for Landing (Airbyte-written)
    landing_table: str    # Table name in Landing
    bronze_table: str     # Table name in Bronze (ammodepot_bronze)
    pk_column: str        # Primary key column for dedup


# Fishbowl tables: all use 'id' except tagserialview (tagid)
FISHBOWL_TABLES = [
    "carrierservice", "customer", "inventorylog", "kititem", "location",
    "objecttoobject", "part", "partcost", "parttotracking", "parttracking",
    "plugininfo", "po", "poitem", "post", "postpo", "postpoitem", "product",
    "receipt", "receiptitem", "serial", "serialnum", "ship", "shipcarton",
    "so", "soitem", "tag", "tagserialview", "uomconversion", "vendor",
    "vendorparts", "wo", "woitem", "xo", "xoitem",
]

FISHBOWL_PK_OVERRIDES = {"tagserialview": "tagid"}

# Magento tables with their primary keys
MAGENTO_TABLE_PKS = {
    "catalog_category_entity_varchar": "value_id",
    "catalog_category_product": "entity_id",
    "catalog_product_entity": "entity_id",
    "catalog_product_entity_decimal": "value_id",
    "catalog_product_entity_int": "value_id",
    "catalog_product_entity_text": "value_id",
    "catalog_product_entity_varchar": "value_id",
    "catalog_product_super_link": "link_id",
    "customer_entity": "entity_id",
    "eav_attribute": "attribute_id",
    "eav_attribute_option_value": "option_id",
    "eav_attribute_set": "attribute_set_id",
    "quote": "entity_id",
    "quote_address": "address_id",
    "quote_address_item": "address_item_id",
    "quote_shipping_rate": "rate_id",
    "sales_order": "entity_id",
    "sales_order_address": "entity_id",
    "sales_order_item": "item_id",
    "sales_shipment_grid": "entity_id",
    "store": "store_id",
}


def build_table_configs(
    source_filter: str | None = None,
    table_filter: list[str] | None = None,
) -> list[TableConfig]:
    """Build list of table configs based on filters."""
    configs = []

    if source_filter is None or source_filter == "fishbowl":
        for table in FISHBOWL_TABLES:
            if table_filter and table not in table_filter:
                continue
            pk = FISHBOWL_PK_OVERRIDES.get(table, "id")
            configs.append(TableConfig(
                landing_db="production2018",
                landing_table=table,
                bronze_table=table,
                pk_column=pk,
            ))

    if source_filter is None or source_filter == "magento":
        for table, pk in MAGENTO_TABLE_PKS.items():
            if table_filter and table not in table_filter:
                continue
            configs.append(TableConfig(
                landing_db="ammuni_prod",
                landing_table=table,
                bronze_table=table,
                pk_column=pk,
            ))

    return configs


def drop_bronze_table(table: str) -> None:
    """Drop a Bronze Iceberg table via AWS Glue API.

    DuckDB's DROP TABLE sends PurgeRequested=true which Glue rejects.
    We delete via Glue API directly and clean up S3 data.
    """
    import boto3

    glue = boto3.client("glue", region_name="us-east-1")
    try:
        glue.delete_table(DatabaseName="ammodepot_bronze", Name=table)
        log.debug("Dropped Glue table: ammodepot_bronze.%s", table)
    except glue.exceptions.EntityNotFoundException:
        pass

    # Clean up S3 data
    s3 = boto3.client("s3", region_name="us-east-1")
    prefix = f"iceberg/ammodepot_bronze.db/{table}/"
    try:
        resp = s3.list_objects_v2(Bucket=S3_BUCKET, Prefix=prefix)
        objects = resp.get("Contents", [])
        while objects:
            s3.delete_objects(
                Bucket=S3_BUCKET,
                Delete={"Objects": [{"Key": o["Key"]} for o in objects]},
            )
            if resp.get("IsTruncated"):
                resp = s3.list_objects_v2(
                    Bucket=S3_BUCKET, Prefix=prefix,
                    ContinuationToken=resp["NextContinuationToken"],
                )
                objects = resp.get("Contents", [])
            else:
                break
    except Exception:
        pass


def build_dedup_sql(cfg: TableConfig) -> str:
    """Generate CTAS SQL: read Landing, dedup by PK, write to Bronze."""
    landing = f"glue.{cfg.landing_db}.{cfg.landing_table}"
    bronze_loc = f"{ICEBERG_PREFIX}/ammodepot_bronze.db/{cfg.bronze_table}"

    return f"""
        CREATE TABLE glue.ammodepot_bronze.{cfg.bronze_table}
        WITH ('location' = '{bronze_loc}')
        AS
        SELECT * EXCLUDE (rn)
        FROM (
            SELECT
                *,
                row_number() OVER (
                    PARTITION BY {cfg.pk_column}
                    ORDER BY coalesce(
                        try_cast(_ab_cdc_updated_at AS timestamp),
                        epoch_ms(_airbyte_extracted_at)
                    ) DESC NULLS LAST
                ) AS rn
            FROM {landing}
        )
        WHERE rn = 1
          AND _ab_cdc_deleted_at IS NULL;
    """


def init_duckdb() -> duckdb.DuckDBPyConnection:
    """Initialize DuckDB with Iceberg + Glue ATTACH."""
    con = duckdb.connect(":memory:")
    con.execute("INSTALL httpfs; LOAD httpfs;")
    con.execute("INSTALL iceberg; LOAD iceberg;")
    con.execute("INSTALL aws; LOAD aws;")
    con.execute("SET s3_region = 'us-east-1';")
    con.execute("SET http_timeout = 600000;")

    # Use default credential chain (IAM role on ECS, or env vars locally)
    con.execute("CREATE SECRET (TYPE s3, PROVIDER credential_chain);")

    con.execute(f"""
        ATTACH '{GLUE_ACCOUNT_ID}' AS glue (
            TYPE iceberg,
            ENDPOINT_TYPE 'GLUE'
        )
    """)
    log.info("DuckDB initialized with Glue catalog")
    return con


def run_dedup(
    configs: list[TableConfig],
    dry_run: bool = False,
) -> dict[str, str]:
    """Run Bronze dedup for all configured tables."""
    results: dict[str, str] = {}

    for cfg in configs:
        sql = build_dedup_sql(cfg)
        table_key = f"{cfg.landing_db}.{cfg.landing_table}"

        if dry_run:
            log.info("DRY RUN: %s → ammodepot_bronze.%s", table_key, cfg.bronze_table)
            for stmt in sql.strip().split(";"):
                stmt = stmt.strip()
                if stmt:
                    print(f"  {stmt};")
            print()
            results[table_key] = "dry_run"
            continue

        log.info("Dedup: %s → ammodepot_bronze.%s (pk=%s)", table_key, cfg.bronze_table, cfg.pk_column)
        t0 = time.time()

        # Fresh connection per table — Glue REST API hangs on reused connections
        con = init_duckdb()
        try:
            # Check if table already exists in Bronze — skip if so
            try:
                count = con.execute(
                    f"SELECT count(*) FROM glue.ammodepot_bronze.{cfg.bronze_table}"
                ).fetchone()[0]
                elapsed = time.time() - t0
                log.info("  SKIP: already exists (%s rows, %.1fs)", f"{count:,}", elapsed)
                results[table_key] = f"skip:{count}"
                continue
            except Exception:
                pass  # Table doesn't exist — proceed with CTAS

            for stmt in sql.strip().split(";"):
                stmt = stmt.strip()
                if stmt:
                    con.execute(stmt)

            # Verify row count
            count = con.execute(
                f"SELECT count(*) FROM glue.ammodepot_bronze.{cfg.bronze_table}"
            ).fetchone()[0]
            elapsed = time.time() - t0
            log.info("  OK: %s rows in %.1fs", f"{count:,}", elapsed)
            results[table_key] = f"ok:{count}"
        except Exception as e:
            elapsed = time.time() - t0
            log.error("  FAIL: %s (%.1fs)", e, elapsed)
            results[table_key] = f"error:{e}"
        finally:
            con.close()

    return results


def main():
    parser = argparse.ArgumentParser(description="Bronze dedup: Landing → Bronze Iceberg")
    parser.add_argument("--source", choices=["fishbowl", "magento"], help="Process one source only")
    parser.add_argument("--tables", help="Comma-separated table names to process")
    parser.add_argument("--dry-run", action="store_true", help="Print SQL without executing")
    args = parser.parse_args()

    table_filter = args.tables.split(",") if args.tables else None
    configs = build_table_configs(source_filter=args.source, table_filter=table_filter)

    log.info("Bronze dedup: %d tables to process", len(configs))
    results = run_dedup(configs, dry_run=args.dry_run)

    # Summary
    ok = sum(1 for v in results.values() if v.startswith("ok:"))
    err = sum(1 for v in results.values() if v.startswith("error:"))
    log.info("Done: %d OK, %d ERROR out of %d total", ok, err, len(results))

    if err > 0:
        for k, v in results.items():
            if v.startswith("error:"):
                log.error("  %s: %s", k, v)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
