# Stages

> **Purpose**: Locations for staging data files before loading into Snowflake tables
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Stages are named locations where data files are stored for loading or unloading. Snowflake supports internal stages (managed by Snowflake) and external stages (referencing cloud storage like S3, GCS, or Azure Blob). Stages are essential for COPY INTO operations and Snowpipe ingestion.

## The Pattern

```sql
-- Internal stage (Snowflake-managed storage)
CREATE STAGE internal_stage
  FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1);

-- External stage pointing to S3
CREATE STAGE s3_stage
  URL = 's3://my-bucket/data/'
  STORAGE_INTEGRATION = my_s3_integration
  FILE_FORMAT = (TYPE = 'PARQUET');

-- External stage pointing to GCS
CREATE STAGE gcs_stage
  URL = 'gcs://my-bucket/data/'
  STORAGE_INTEGRATION = my_gcs_integration;

-- List files in stage
LIST @s3_stage/2024/01/;

-- Upload file to internal stage (via SnowSQL)
-- PUT file://local/path/data.csv @internal_stage;

-- Query staged files directly
SELECT $1, $2, $3 FROM @s3_stage/sample.csv (FILE_FORMAT => 'my_csv_format');
```

## Quick Reference

| Stage Type | Storage Location | Use Case |
|------------|------------------|----------|
| User Stage | `@~` | Personal, temporary files |
| Table Stage | `@%table_name` | Table-specific staging |
| Named Internal | `@stage_name` | Shared internal storage |
| Named External | `@stage_name` | Cloud storage (S3/GCS/Azure) |

| Command | Purpose |
|---------|---------|
| `LIST @stage` | View files in stage |
| `PUT` | Upload to internal stage |
| `GET` | Download from internal stage |
| `REMOVE @stage/path` | Delete staged files |

## Common Mistakes

### Wrong

```sql
-- Hardcoding credentials in stage definition
CREATE STAGE bad_stage
  URL = 's3://bucket/'
  CREDENTIALS = (AWS_KEY_ID = 'AKIA...' AWS_SECRET_KEY = '...');

-- Not specifying file format
COPY INTO table FROM @stage;  -- Assumes defaults
```

### Correct

```sql
-- Use storage integration for secure access
CREATE STORAGE INTEGRATION s3_int
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789:role/snowflake-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://my-bucket/');

CREATE STAGE secure_stage
  URL = 's3://my-bucket/data/'
  STORAGE_INTEGRATION = s3_int
  FILE_FORMAT = (TYPE = 'JSON');
```

## Related

- [copy-into-loading](../patterns/copy-into-loading.md)
- [snowpipe-streaming](../patterns/snowpipe-streaming.md)
