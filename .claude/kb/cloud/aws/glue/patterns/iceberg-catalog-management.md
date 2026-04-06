# AWS Glue as Iceberg Catalog

## Overview

AWS Glue Data Catalog serves as an Apache Iceberg catalog, managing table metadata while data lives in S3. Supports reads from Snowflake, DuckDB, Athena, Spark, and other engines.

## Database Management

### Create with LocationUri (required for DuckDB writes)

```bash
aws glue create-database --database-input '{
    "Name": "my_database",
    "LocationUri": "s3://my-bucket/iceberg/my_database.db",
    "Description": "Iceberg tables for my layer"
}'
```

### Table Operations

```bash
# List tables
aws glue get-tables --database-name my_database --query 'TableList[].Name'

# Delete table (when DuckDB DROP TABLE fails with PurgeRequested)
aws glue delete-table --database-name my_database --name my_table

# Get table details
aws glue get-table --database-name my_database --name my_table
```

## Airbyte S3 Data Lake Destination + Glue

Airbyte's S3 Data Lake (Iceberg) destination creates Glue databases automatically:
- Database name = source namespace (e.g., `production2018` for MySQL CDC)
- NOT configurable via `database_name` field (ignores it when using namespace)
- Tables named after stream names (lowercase)
- Append mode only — `append_dedup` fails on null PKs from CDC deletes (Airbyte v1.5.1)

### Airbyte Iceberg Table Structure

```
s3://bucket/iceberg/{namespace}.db/{table_name}/
├── data/
│   └── 00000-1-uuid.parquet
└── metadata/
    ├── 00000-uuid.metadata.json
    ├── 00001-uuid.metadata.json
    └── snap-*.avro
```

- No `version-hint.text` file — DuckDB's `iceberg_scan()` can't auto-detect version
- Use Glue catalog ATTACH instead of direct `iceberg_scan()` paths

## Glue Table Optimizers

Available for Glue-managed Iceberg tables (auto-enabled):

| Optimizer | Purpose | When to Use |
|-----------|---------|------------|
| Compaction | Merge small files | After CDC writes (many small Parquet files) |
| Snapshot retention | Clean old snapshots | Keep 7 days, drop older |
| Orphan file deletion | Remove unreferenced data | After full-overwrite writes |

```bash
aws glue create-table-optimizer \
    --catalog-id <account-id> \
    --database-name my_database \
    --table-name my_table \
    --type compaction \
    --table-optimizer-configuration '{"enabled": true, "roleArn": "arn:aws:iam::<account>:role/AWSGlueServiceRole"}'
```

## IAM Permissions

### For Glue catalog access (read)

```json
{
    "Action": [
        "glue:GetTable", "glue:GetTables",
        "glue:GetDatabase", "glue:GetDatabases"
    ],
    "Resource": [
        "arn:aws:glue:<region>:<account>:catalog",
        "arn:aws:glue:<region>:<account>:database/*",
        "arn:aws:glue:<region>:<account>:table/*/*"
    ]
}
```

### For Glue catalog access (read + write)

Add: `glue:CreateDatabase`, `glue:CreateTable`, `glue:UpdateTable`, `glue:DeleteTable`, `glue:GetTableVersion`, `glue:GetTableVersions`, `glue:DeleteTableVersion`

## Multi-Engine Access Pattern

Same Iceberg tables readable by multiple engines simultaneously:

```
Airbyte → S3 Iceberg (writes via Glue)
    ↓
DuckDB reads via ATTACH (analytics/transforms)
Snowflake reads via External Volume + Catalog Integration
Athena reads via Glue catalog (ad-hoc queries)
```
