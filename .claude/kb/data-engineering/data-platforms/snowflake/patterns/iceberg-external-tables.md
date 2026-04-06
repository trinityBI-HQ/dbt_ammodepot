# Snowflake Iceberg External Tables via Glue Catalog

## Overview

Snowflake can read Apache Iceberg tables directly from S3 via AWS Glue Data Catalog, eliminating the need for COPY INTO or data duplication. Tables appear as native Snowflake objects but data stays in S3.

## Setup (One-Time, ACCOUNTADMIN)

### 1. Catalog Integration (Glue → Snowflake)

```sql
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE CATALOG INTEGRATION lakehouse_glue_catalog
    CATALOG_SOURCE = GLUE
    CATALOG_NAMESPACE = 'default_namespace'
    TABLE_FORMAT = ICEBERG
    GLUE_AWS_ROLE_ARN = 'arn:aws:iam::<account>:role/<role-name>'
    GLUE_CATALOG_ID = '<aws-account-id>'
    GLUE_REGION = 'us-east-1'
    ENABLED = TRUE;
```

### 2. External Volume (S3 access)

```sql
CREATE OR REPLACE EXTERNAL VOLUME lakehouse_s3_volume
    STORAGE_LOCATIONS = (
        (
            NAME = 'my-bucket'
            STORAGE_BASE_URL = 's3://<bucket>/iceberg/'
            STORAGE_PROVIDER = 'S3'
            STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<account>:role/<role-name>'
        )
    );
```

### 3. IAM Trust Policy

After creating both objects, run DESCRIBE to get Snowflake's IAM ARN and External ID:

```sql
DESCRIBE CATALOG INTEGRATION lakehouse_glue_catalog;
-- Note: GLUE_AWS_IAM_USER_ARN, GLUE_AWS_EXTERNAL_ID

DESCRIBE EXTERNAL VOLUME lakehouse_s3_volume;
-- Note: STORAGE_AWS_IAM_USER_ARN, STORAGE_AWS_EXTERNAL_ID
```

Update the IAM role trust policy with both principals.

### 4. Grant to non-admin roles

```sql
GRANT USAGE ON INTEGRATION lakehouse_glue_catalog TO ROLE TRANSFORMER_ROLE;
GRANT USAGE ON EXTERNAL VOLUME lakehouse_s3_volume TO ROLE TRANSFORMER_ROLE;
```

## Creating Iceberg Tables (TRANSFORMER_ROLE)

```sql
CREATE OR REPLACE ICEBERG TABLE MY_SCHEMA.MY_TABLE
    EXTERNAL_VOLUME = 'lakehouse_s3_volume'
    CATALOG = 'lakehouse_glue_catalog'
    CATALOG_TABLE_NAME = 'table_name_in_glue'
    CATALOG_NAMESPACE = 'glue_database_name';
```

- `CATALOG_NAMESPACE` = Glue database name
- `CATALOG_TABLE_NAME` = Glue table name (case-sensitive)
- Snowflake auto-refreshes metadata (default 30s interval)

## Using with dbt Sources

Use `identifier` to map dbt source names to Snowflake Iceberg table names:

```yaml
sources:
  - name: fishbowl
    database: AD_ANALYTICS
    schema: LAKEHOUSE_LANDING
    tables:
      - name: so
        identifier: FISHBOWL_SO  # Maps to Snowflake Iceberg table name
```

## Key Considerations

- **IAM role needs PutObject** — Snowflake writes a test file on CREATE ICEBERG TABLE
- **No result caching** on external Iceberg tables (unlike native tables)
- **Metadata refresh** adds ~1-2s latency per query vs native tables
- **Column types** from Iceberg may differ from Airbyte Snowflake tables (VARCHAR vs TIMESTAMP for CDC fields)
- **Predicate pushdown** and **column pruning** work — only reads needed Parquet files
- **REFRESH_INTERVAL_SECONDS** defaults to 30 — controls how often Snowflake checks for new Iceberg snapshots
