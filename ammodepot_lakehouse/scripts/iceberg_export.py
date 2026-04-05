"""Iceberg Export: Read dbt views from DuckDB and write to Glue Iceberg catalog.

After dbt creates Silver/Gold views in DuckDB's in-memory database, this script
reads each view and writes it as an Iceberg table to the target Glue database.

DuckDB 1.5.1 crashes when dbt writes directly to Glue (schema introspection
segfault), so this script bridges the gap.

Usage:
    # Export Silver views to ammodepot_silver Iceberg
    python iceberg_export.py --layer silver

    # Export Gold views to ammodepot_gold Iceberg
    python iceberg_export.py --layer gold

    # Export specific models
    python iceberg_export.py --layer silver --models fishbowl_so,fishbowl_soitem

    # Dry run
    python iceberg_export.py --layer silver --dry-run
"""

import argparse
import logging
import subprocess
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


def get_dbt_models(layer: str) -> list[str]:
    """Get list of dbt model names for a layer by scanning the models directory."""
    import glob
    import os

    base = os.path.join(os.path.dirname(__file__), "..", "models", layer)
    models = []
    for f in glob.glob(os.path.join(base, "**/*.sql"), recursive=True):
        name = os.path.basename(f).replace(".sql", "")
        models.append(name)
    return sorted(models)


def run_dbt_views(layer: str, models: list[str] | None = None) -> None:
    """Run dbt to create views in DuckDB's in-memory database."""
    cmd = ["uv", "run", "dbt", "run", "--profiles-dir", ".", "--select"]
    if models:
        cmd.extend(models)
    else:
        cmd.append(layer)

    log.info("Running dbt to create %s views...", layer)
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    if result.returncode != 0:
        log.error("dbt failed:\n%s", result.stdout[-1000:] if result.stdout else result.stderr[-1000:])
        raise RuntimeError(f"dbt run failed with exit code {result.returncode}")

    # Count passes
    for line in result.stdout.split("\n"):
        if "Done." in line:
            log.info("dbt: %s", line.strip())


def init_duckdb_with_views(layer: str, models: list[str] | None = None) -> duckdb.DuckDBPyConnection:
    """Initialize DuckDB, run dbt to create views, then attach Glue for writing."""
    con = duckdb.connect(":memory:")
    con.execute("INSTALL httpfs; LOAD httpfs;")
    con.execute("INSTALL iceberg; LOAD iceberg;")
    con.execute("INSTALL aws; LOAD aws;")
    con.execute("SET s3_region = 'us-east-1';")
    con.execute("SET http_timeout = 600000;")
    con.execute("SET memory_limit = '12GB';")
    con.execute("CREATE SECRET (TYPE s3, PROVIDER credential_chain);")

    # Attach Glue catalog for reading Bronze sources
    con.execute(f"""
        ATTACH '{GLUE_ACCOUNT_ID}' AS glue (
            TYPE iceberg,
            ENDPOINT_TYPE 'GLUE'
        )
    """)
    log.info("DuckDB initialized with Glue catalog")
    return con


def create_views_in_duckdb(
    con: duckdb.DuckDBPyConnection,
    layer: str,
    models: list[str] | None = None,
) -> list[str]:
    """Execute dbt-compiled SQL to create views in DuckDB, return model names."""
    import glob
    import os

    compiled_dir = os.path.join(
        os.path.dirname(__file__), "..", "target", "compiled",
        "ammodepot_lakehouse", "models", layer,
    )

    # First run dbt compile to generate SQL
    cmd = ["uv", "run", "dbt", "compile", "--profiles-dir", "."]
    if models:
        cmd.extend(["--select"] + models)
    else:
        cmd.extend(["--select", layer])

    log.info("Compiling dbt %s models...", layer)
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        log.error("dbt compile failed:\n%s", result.stderr[-500:])
        raise RuntimeError("dbt compile failed")

    # Find all compiled SQL files
    created = []
    sql_files = sorted(glob.glob(os.path.join(compiled_dir, "**/*.sql"), recursive=True))
    for sql_file in sql_files:
        name = os.path.basename(sql_file).replace(".sql", "")
        if models and name not in models:
            continue

        with open(sql_file) as f:
            sql = f.read().strip()

        if not sql:
            continue

        # Create as view in DuckDB memory
        try:
            con.execute(f"CREATE OR REPLACE VIEW {name} AS ({sql})")
            created.append(name)
        except Exception as e:
            log.error("Failed to create view %s: %s", name, e)

    log.info("Created %d views in DuckDB", len(created))
    return created


def drop_iceberg_table(glue_db: str, table: str) -> None:
    """Drop an Iceberg table via Glue API + S3 cleanup."""
    glue = boto3.client("glue", region_name="us-east-1")
    try:
        glue.delete_table(DatabaseName=glue_db, Name=table)
    except glue.exceptions.EntityNotFoundException:
        pass

    s3 = boto3.client("s3", region_name="us-east-1")
    prefix = f"iceberg/{glue_db}.db/{table}/"
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


def export_to_iceberg(
    con: duckdb.DuckDBPyConnection,
    view_names: list[str],
    glue_db: str,
    dry_run: bool = False,
) -> dict[str, str]:
    """Export DuckDB views to Iceberg tables in Glue catalog."""
    results: dict[str, str] = {}

    for name in view_names:
        s3_location = f"{ICEBERG_PREFIX}/{glue_db}.db/{name}"

        if dry_run:
            log.info("DRY RUN: %s → glue.%s.%s", name, glue_db, name)
            print(f"  DROP + CREATE TABLE glue.{glue_db}.{name}")
            print(f"  WITH ('location' = '{s3_location}')")
            print(f"  AS SELECT * FROM {name};")
            results[name] = "dry_run"
            continue

        log.info("Export: %s → glue.%s.%s", name, glue_db, name)
        t0 = time.time()

        try:
            # Drop existing via Glue API
            drop_iceberg_table(glue_db, name)

            # Write to Iceberg
            con.execute(f"""
                CREATE TABLE glue.{glue_db}.{name}
                WITH ('location' = '{s3_location}')
                AS SELECT * FROM {name}
            """)

            count = con.execute(
                f"SELECT count(*) FROM glue.{glue_db}.{name}"
            ).fetchone()[0]
            elapsed = time.time() - t0
            log.info("  OK: %s rows in %.1fs", f"{count:,}", elapsed)
            results[name] = f"ok:{count}"
        except Exception as e:
            elapsed = time.time() - t0
            log.error("  FAIL: %s (%.1fs)", e, elapsed)
            results[name] = f"error:{e}"

    return results


def main():
    parser = argparse.ArgumentParser(description="Export dbt views to Glue Iceberg")
    parser.add_argument("--layer", required=True, choices=["silver", "gold"],
                        help="Layer to export")
    parser.add_argument("--models", help="Comma-separated model names")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    glue_db = f"ammodepot_{args.layer}"
    model_filter = args.models.split(",") if args.models else None

    # Initialize DuckDB with Glue ATTACH
    con = init_duckdb_with_views(args.layer, model_filter)

    # Create dbt views in DuckDB memory
    view_names = create_views_in_duckdb(con, args.layer, model_filter)
    if not view_names:
        log.error("No views created — check dbt compile output")
        raise SystemExit(1)

    # Export views to Iceberg
    results = export_to_iceberg(con, view_names, glue_db, dry_run=args.dry_run)
    con.close()

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
