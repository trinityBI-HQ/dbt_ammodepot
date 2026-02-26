# Data Catalog

> **Purpose**: Centralized metadata repository for all data assets
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The AWS Glue Data Catalog is a persistent, Apache Hive metastore-compatible metadata store. It stores table definitions, partition information, and schema metadata for data stored in S3, JDBC sources, and streaming endpoints. It serves as the central schema registry for Athena, Redshift Spectrum, EMR, and Lake Formation.

## Key Components

| Component | Description |
|-----------|-------------|
| **Database** | Logical namespace grouping related tables |
| **Table** | Schema definition pointing to underlying data |
| **Partition** | Subset of table data stored in a specific S3 prefix |
| **Column** | Individual field with name, type, and optional comment |
| **Connection** | Access credentials and network config for data stores |
| **View** | Virtual table defined by SQL, queryable across engines (Glue 5.0+) |
| **Materialized View** | Precomputed Iceberg-backed view for faster queries (Glue 5.1+) |

## The Pattern

```python
import boto3

glue = boto3.client("glue")

# Create a database
glue.create_database(
    DatabaseInput={
        "Name": "sales_db",
        "Description": "Sales data lake tables",
        "LocationUri": "s3://my-data-lake/sales/",
    }
)

# Create a table definition
glue.create_table(
    DatabaseName="sales_db",
    TableInput={
        "Name": "orders",
        "StorageDescriptor": {
            "Columns": [
                {"Name": "order_id", "Type": "string"},
                {"Name": "amount", "Type": "decimal(10,2)"},
                {"Name": "created_at", "Type": "timestamp"},
            ],
            "Location": "s3://my-data-lake/sales/orders/",
            "InputFormat": "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat",
            "OutputFormat": "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat",
            "SerdeInfo": {"SerializationLibrary": "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"},
        },
        "PartitionKeys": [
            {"Name": "year", "Type": "string"},
            {"Name": "month", "Type": "string"},
        ],
        "TableType": "EXTERNAL_TABLE",
    },
)
```

## Hive Metastore Compatibility

The Data Catalog can replace a standalone Hive Metastore:
- Athena uses it natively as its metadata store
- EMR can configure `hive.metastore.client.factory.class` to use the Catalog
- Redshift Spectrum reads table definitions from the Catalog
- Spark on Glue uses it by default via `GlueContext`

## Partition Indexes

Partition indexes accelerate query planning when tables have millions of partitions:

```python
glue.create_partition_index(
    DatabaseName="sales_db",
    TableName="orders",
    PartitionIndex={"Keys": ["year", "month"], "IndexName": "year_month_idx"},
)
```

Without indexes, every `get_partitions` call scans all partitions sequentially.

## Quick Reference

| Limit | Value |
|-------|-------|
| Databases per account | 10,000 |
| Tables per database | 3,000,000 |
| Partitions per table | 10,000,000 |
| Versions per table | 100,000 |
| Columns per table | 400 (Athena), unlimited (Glue) |

## Data Catalog Views (Glue 5.0+)

Data Catalog views are virtual tables defined by SQL that can be queried across Athena, EMR, and Glue ETL. Unlike Athena-only views, catalog views are engine-agnostic:

```python
# Create a Data Catalog view via API
glue.create_table(
    DatabaseName="sales_db",
    TableInput={
        "Name": "active_orders_view",
        "TableType": "VIRTUAL_VIEW",
        "ViewOriginalText": "SELECT * FROM orders WHERE status = 'active'",
        "ViewExpandedText": "SELECT * FROM sales_db.orders WHERE status = 'active'",
        "Parameters": {"presto_view": "true"},
    },
)
```

## Iceberg Materialized Views (Glue 5.1+)

Materialized views store precomputed results as Iceberg tables, queryable via Athena SQL:

- Backed by Iceberg format for ACID guarantees
- Queryable from Athena (Nov 2025+)
- Automatic or manual refresh strategies
- Useful for expensive aggregations or cross-table joins

## Common Mistakes

### Wrong

```python
# Registering partitions manually one-by-one
for partition in partitions:
    glue.create_partition(...)  # N API calls = slow + throttled
```

### Correct

```python
# Batch register partitions (up to 100 per call)
glue.batch_create_partition(
    DatabaseName="sales_db",
    TableName="orders",
    PartitionInputList=partition_batch,  # List of up to 100
)
```

## Related

- [Crawlers](../concepts/crawlers.md) -- auto-discover and register schemas
- [Catalog Management](../patterns/catalog-management.md) -- naming and organization
