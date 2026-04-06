"""Create Snowflake Iceberg tables for all Silver + Gold Glue catalog tables.

After the Catalog Integration + External Volume are created (see snowflake_iceberg_setup.sql),
this script creates Iceberg tables in Snowflake that read from the Glue catalog.

Usage:
    python snowflake_iceberg_tables.py --setup-trust   # Update IAM trust policy
    python snowflake_iceberg_tables.py --create-tables  # Create all Iceberg tables
    python snowflake_iceberg_tables.py --verify         # Verify tables are readable
"""

import argparse
import json
import logging
import os

import boto3
import snowflake.connector

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

AWS_ACCOUNT_ID = "746669199691"
IAM_ROLE_NAME = "snowflake-lakehouse-role"
CATALOG_INTEGRATION = "lakehouse_glue_catalog"
EXTERNAL_VOLUME = "lakehouse_s3_volume"
TARGET_DB = "AD_ANALYTICS"

LAYER_CONFIG = {
    "silver": {
        "glue_db": "ammodepot_silver",
        "sf_schema": "LAKEHOUSE_SILVER",
    },
    "gold": {
        "glue_db": "ammodepot_gold",
        "sf_schema": "LAKEHOUSE_GOLD",
    },
}


def get_snowflake_conn(role: str = "TRANSFORMER_ROLE") -> snowflake.connector.SnowflakeConnection:
    key_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..", "ammodepot", "dbt_rsa_key.p8"
    )
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key_file=key_path,
        private_key_file_pwd=os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE", "").encode(),
        database=TARGET_DB,
        warehouse="ETL_WH",
        role=role,
    )


def setup_trust_policy(conn):
    """Get Snowflake IAM ARN + External IDs and update the IAM trust policy."""
    cur = conn.cursor()

    # Get catalog integration details (property, property_type, property_value, property_default)
    cur.execute(f"DESCRIBE CATALOG INTEGRATION {CATALOG_INTEGRATION}")
    catalog_rows = {r[0]: r[2] for r in cur.fetchall()}
    catalog_arn = catalog_rows.get("GLUE_AWS_IAM_USER_ARN", "")
    catalog_ext_id = catalog_rows.get("GLUE_AWS_EXTERNAL_ID", "")
    log.info("Catalog IAM ARN: %s", catalog_arn)
    log.info("Catalog External ID: %s", catalog_ext_id)

    # Get external volume details (parent_property, property, property_type, property_value, property_default)
    cur.execute(f"DESCRIBE EXTERNAL VOLUME {EXTERNAL_VOLUME}")
    vol_arn = ""
    vol_ext_id = ""
    for row in cur.fetchall():
        if row[1] == "STORAGE_LOCATION_1":
            props = json.loads(row[3]) if isinstance(row[3], str) else {}
            vol_arn = props.get("STORAGE_AWS_IAM_USER_ARN", "")
            vol_ext_id = props.get("STORAGE_AWS_EXTERNAL_ID", "")

    log.info("Volume IAM ARN: %s", vol_arn)
    log.info("Volume External ID: %s", vol_ext_id)
    cur.close()

    if not catalog_arn or not vol_arn:
        log.error("Could not retrieve ARNs. Run the setup SQL first.")
        raise SystemExit(1)

    # Build trust policy with both Snowflake principals
    principals = list(set(filter(None, [catalog_arn, vol_arn])))
    external_ids = list(set(filter(None, [catalog_ext_id, vol_ext_id])))

    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {"AWS": principals},
                "Action": "sts:AssumeRole",
                "Condition": {
                    "StringEquals": {
                        "sts:ExternalId": external_ids
                    }
                },
            }
        ],
    }

    log.info("Updating IAM trust policy for %s...", IAM_ROLE_NAME)
    iam = boto3.client("iam", region_name="us-east-1")
    iam.update_assume_role_policy(
        RoleName=IAM_ROLE_NAME,
        PolicyDocument=json.dumps(trust_policy),
    )
    log.info("Trust policy updated with %d principal(s)", len(principals))


def create_tables(conn):
    """Create Iceberg tables in Snowflake for all Glue catalog tables."""
    cur = conn.cursor()
    cur.execute(f"USE ROLE TRANSFORMER_ROLE")
    cur.execute(f"USE DATABASE {TARGET_DB}")
    cur.execute(f"USE WAREHOUSE ETL_WH")

    glue = boto3.client("glue", region_name="us-east-1")

    for layer, cfg in LAYER_CONFIG.items():
        sf_schema = cfg["sf_schema"]
        glue_db = cfg["glue_db"]

        cur.execute(f"CREATE SCHEMA IF NOT EXISTS {sf_schema}")
        log.info("Schema %s ready", sf_schema)

        # Get all tables from Glue
        tables = glue.get_tables(DatabaseName=glue_db)["TableList"]
        log.info("Found %d %s tables in Glue", len(tables), layer)

        ok, fail = 0, 0
        for table in tables:
            name = table["Name"]
            sf_name = name.upper()

            try:
                cur.execute(f"""
                    CREATE OR REPLACE ICEBERG TABLE {sf_schema}.{sf_name}
                        EXTERNAL_VOLUME = '{EXTERNAL_VOLUME}'
                        CATALOG = '{CATALOG_INTEGRATION}'
                        CATALOG_TABLE_NAME = '{name}'
                        CATALOG_NAMESPACE = '{glue_db}'
                """)
                log.info("  %s.%s: OK", sf_schema, sf_name)
                ok += 1
            except Exception as e:
                log.error("  %s.%s: FAIL - %s", sf_schema, sf_name, str(e)[:200])
                fail += 1

        log.info("%s: %d OK, %d FAIL", layer, ok, fail)

    cur.close()


def verify_tables(conn):
    """Verify Iceberg tables are readable."""
    cur = conn.cursor()
    cur.execute(f"USE ROLE TRANSFORMER_ROLE")
    cur.execute(f"USE DATABASE {TARGET_DB}")

    for layer, cfg in LAYER_CONFIG.items():
        sf_schema = cfg["sf_schema"]
        cur.execute(f"SHOW ICEBERG TABLES IN SCHEMA {sf_schema}")
        tables = cur.fetchall()
        log.info("%s: %d Iceberg tables", sf_schema, len(tables))

        # Test a few
        for table in tables[:3]:
            name = table[1]
            try:
                cur.execute(f"SELECT count(*) FROM {sf_schema}.{name}")
                cnt = cur.fetchone()[0]
                log.info("  %s.%s: %s rows", sf_schema, name, f"{cnt:,}")
            except Exception as e:
                log.error("  %s.%s: %s", sf_schema, name, str(e)[:200])

    cur.close()


def main():
    parser = argparse.ArgumentParser(description="Snowflake Iceberg table management")
    parser.add_argument("--setup-trust", action="store_true",
                        help="Update IAM trust policy with Snowflake ARNs")
    parser.add_argument("--create-tables", action="store_true",
                        help="Create Iceberg tables in Snowflake")
    parser.add_argument("--verify", action="store_true",
                        help="Verify Iceberg tables are readable")
    args = parser.parse_args()

    # Load env
    env_path = os.path.join(os.path.dirname(__file__), "..", "..", "ammodepot", ".env")
    if os.path.exists(env_path):
        from dotenv import load_dotenv
        load_dotenv(env_path)

    if args.setup_trust:
        conn = get_snowflake_conn(role="TRANSFORMER_ROLE")
        log.info("Connected as TRANSFORMER_ROLE")
        setup_trust_policy(conn)
        conn.close()
    elif args.create_tables:
        conn = get_snowflake_conn(role="TRANSFORMER_ROLE")
        log.info("Connected as TRANSFORMER_ROLE")
        create_tables(conn)
        conn.close()
    elif args.verify:
        conn = get_snowflake_conn(role="TRANSFORMER_ROLE")
        log.info("Connected as TRANSFORMER_ROLE")
        verify_tables(conn)
        conn.close()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
