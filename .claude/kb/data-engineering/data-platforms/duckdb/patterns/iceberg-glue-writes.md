# DuckDB Iceberg Writes to AWS Glue Catalog

## Overview

DuckDB 1.5.1+ can read AND write Iceberg tables via the AWS Glue catalog using the `ATTACH` command. Writes are experimental with known limitations.

## Setup

```sql
INSTALL httpfs; LOAD httpfs;
INSTALL iceberg; LOAD iceberg;
INSTALL aws; LOAD aws;

SET s3_region = 'us-east-1';
CREATE SECRET (TYPE s3, KEY_ID '...', SECRET '...', REGION 'us-east-1');

ATTACH '<aws-account-id>' AS glue (TYPE iceberg, ENDPOINT_TYPE 'GLUE');
```

## Reading (Stable)

```sql
SELECT * FROM glue.my_database.my_table;
SELECT count(*) FROM glue.my_database.my_table;
```

Works reliably. DuckDB reads Iceberg metadata from Glue, fetches Parquet data from S3.

## Writing (Experimental)

### CREATE TABLE — requires WITH ('location' = ...)

Glue REST API requires a `location` per table. DuckDB doesn't auto-derive it.

```sql
CREATE TABLE glue.my_database.my_table
WITH ('location' = 's3://my-bucket/iceberg/my_database.db/my_table')
AS SELECT 1 AS id, 42 AS value;
```

Without the `WITH` clause: `BadRequest_400: Cannot parse missing string: location`

### INSERT / DELETE (work on non-partitioned tables)

```sql
INSERT INTO glue.my_database.my_table VALUES (2, 84);
DELETE FROM glue.my_database.my_table WHERE id = 2;
```

### Glue Database Setup

Each Glue database needs `LocationUri` set:

```bash
aws glue create-database --database-input '{
    "Name": "my_database",
    "LocationUri": "s3://my-bucket/iceberg/my_database.db"
}'
```

## Known Limitations (DuckDB 1.5.1)

| Issue | Workaround |
|-------|------------|
| `CREATE OR REPLACE` not supported | DROP then CREATE |
| `MERGE INTO` not supported | DELETE + INSERT pattern |
| `DROP TABLE` sends PurgeRequested=true (Glue rejects) | Delete via boto3 Glue API + S3 cleanup |
| Schema introspection crashes (segfault) when dbt lists schemas | Don't use dbt-duckdb to write to Glue directly |
| Connection hangs after ~8 sequential Iceberg writes | Fresh DuckDB connection per table |
| No `version-hint.text` from Airbyte | Use Glue ATTACH instead of `iceberg_scan()` |
| `unsafe_enable_version_guessing` doesn't work with Airbyte's metadata naming | Use Glue catalog (bypasses version guessing) |

## Performance Notes

| Operation | 7M rows | Notes |
|-----------|---------|-------|
| Read (Iceberg → DuckDB) | ~18s | Fast for analytics-scale |
| Write (CTAS → Iceberg) | ~4 min | With optimized dedup (aggregate+join) |
| Write (CTAS + ROW_NUMBER) | 2+ hours | Avoid window functions on large writes |
| Pre-cache all Silver (76 tables) | OOM | Don't load everything into one session |

## Recommendation

DuckDB + Glue Iceberg works for POC/validation but is too experimental for production pipelines. For production, use Snowflake Iceberg External Tables (reads Glue catalog natively) or AWS Glue Serverless (native Spark Iceberg support).
