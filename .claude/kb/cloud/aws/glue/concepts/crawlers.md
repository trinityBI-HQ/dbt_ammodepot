# Crawlers

> **Purpose**: Automatic schema discovery and metadata registration
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Glue Crawlers scan data stores (S3, JDBC, DynamoDB) to infer schemas, detect partitions, and register or update table definitions in the Data Catalog. They use classifiers to identify data formats and automatically handle schema evolution.

## How Crawlers Work

```
1. Crawler connects to data store (S3 path, JDBC endpoint)
2. Classifiers identify format (Parquet, JSON, CSV, Avro, ORC)
3. Schema inferred from data samples
4. Partitions detected from S3 prefix structure
5. Tables created/updated in Data Catalog
```

## The Pattern

```python
import boto3

glue = boto3.client("glue")

glue.create_crawler(
    Name="sales-crawler",
    Role="arn:aws:iam::role/GlueCrawlerRole",
    DatabaseName="sales_db",
    Targets={
        "S3Targets": [
            {
                "Path": "s3://data-lake/sales/orders/",
                "Exclusions": ["**/_temporary/**", "**/_spark_metadata/**"],
            }
        ]
    },
    SchemaChangePolicy={
        "UpdateBehavior": "UPDATE_IN_DATABASE",
        "DeleteBehavior": "LOG",  # Don't auto-delete columns
    },
    RecrawlPolicy={"RecrawlBehavior": "CRAWL_NEW_FOLDERS_ONLY"},
    Schedule={"ScheduleExpression": "cron(0 6 * * ? *)"},  # Daily 6AM UTC
    Configuration=json.dumps({
        "Version": 1.0,
        "Grouping": {"TableGroupingPolicy": "CombineCompatibleSchemas"},
    }),
)
```

## Classifiers

Built-in classifiers handle common formats. Custom classifiers for non-standard data:

| Type | Formats |
|------|---------|
| **Built-in** | Parquet, ORC, Avro, JSON, CSV, Ion, XML |
| **Grok** | Custom log patterns (Apache, syslog, etc.) |
| **JSON** | Custom JSON path expressions |
| **CSV** | Custom delimiters, quote chars, headers |
| **XML** | Custom row tags |

```python
# Custom CSV classifier for pipe-delimited files
glue.create_classifier(
    CsvClassifier={
        "Name": "pipe-delimited",
        "Delimiter": "|",
        "QuoteSymbol": '"',
        "ContainsHeader": "PRESENT",
        "AllowSingleColumn": False,
    }
)
```

## Partition Detection

Crawlers auto-detect Hive-style partitions from S3 prefixes:

```
s3://bucket/orders/year=2025/month=01/data.parquet
s3://bucket/orders/year=2025/month=02/data.parquet
→ Partition keys: year (string), month (string)
```

Non-Hive paths are detected by position:
```
s3://bucket/orders/2025/01/data.parquet
→ Partition keys: partition_0, partition_1
```

## Recrawl Policies

| Policy | Behavior | Use Case |
|--------|----------|----------|
| `CRAWL_EVERYTHING` | Rescan all data | Schema changes, repair |
| `CRAWL_NEW_FOLDERS_ONLY` | Only new S3 prefixes | Append-only data lakes |
| `CRAWL_EVENT_BASED` | Triggered by S3 events | Real-time catalog updates |

## Schema Evolution

| Change | Default Behavior |
|--------|-----------------|
| New column added | Column appended to table |
| Column removed | Kept in schema (LOG policy) |
| Type change | Updated if compatible |
| New partition | Auto-registered |

## Common Mistakes

### Wrong

```python
# Running crawler before every ETL job
# Crawlers are slow (minutes) and have API throttling limits
```

### Correct

```python
# Schedule crawlers independently; use batch_create_partition
# for known schemas to register new partitions instantly
glue.batch_create_partition(
    DatabaseName="sales_db",
    TableName="orders",
    PartitionInputList=[...],
)
```

## Related

- [Data Catalog](../concepts/data-catalog.md)
- [Catalog Management](../patterns/catalog-management.md)
