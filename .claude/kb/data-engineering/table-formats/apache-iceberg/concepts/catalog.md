# Iceberg Catalogs

> **Purpose**: Understand catalog types, their trade-offs, and configuration
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

An Iceberg catalog is the service that tracks the **current metadata pointer** for each table. It's the entry point for all table operations — without a catalog, engines cannot find or modify tables. The catalog handles atomic metadata updates and namespace management.

## Catalog Types

| Catalog | Backend | Multi-Engine | Best For |
|---------|---------|:------------:|----------|
| **REST** | HTTP API (Polaris, Tabular, etc.) | Yes | Production, multi-engine |
| **Hive Metastore** | HMS (Thrift) | Yes | Existing Hive ecosystems |
| **AWS Glue** | AWS Glue Data Catalog | Yes | AWS-native stacks |
| **Nessie** | Nessie server (Git-like) | Yes | Branching/versioning workflows |
| **JDBC** | Relational DB (Postgres, MySQL) | Yes | Simple self-hosted |
| **Hadoop** | File system (HDFS/S3) | Limited | Dev/testing only |

## REST Catalog (Recommended)

The **Iceberg REST Catalog Protocol** is an open specification that any service can implement. It decouples catalog logic from compute engines.

```python
# Spark configuration for REST catalog
spark = SparkSession.builder \
    .config("spark.sql.catalog.my_catalog", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.my_catalog.type", "rest") \
    .config("spark.sql.catalog.my_catalog.uri", "https://catalog.example.com") \
    .config("spark.sql.catalog.my_catalog.warehouse", "s3://my-bucket/warehouse") \
    .config("spark.sql.catalog.my_catalog.credential", "client-id:client-secret") \
    .getOrCreate()
```

**Key REST endpoints:**
- `GET /v1/config` — catalog configuration
- `GET /v1/namespaces` — list namespaces
- `GET /v1/namespaces/{ns}/tables` — list tables
- `GET /v1/namespaces/{ns}/tables/{table}` — load table metadata
- `POST /v1/namespaces/{ns}/tables/{table}` — commit metadata update

### Apache Polaris (Incubating)

Apache Polaris is a standalone REST catalog implementation (Apache incubating project) that supports:
- Multi-engine access (Spark, Trino, Flink, Dremio)
- Fine-grained access control (RBAC)
- **Delta Lake interoperability** (read Delta tables via Iceberg compatibility)
- **PostgreSQL persistence** backend (in addition to in-memory)
- Open-source alternative to proprietary REST catalogs

## AWS Glue Catalog

```python
spark = SparkSession.builder \
    .config("spark.sql.catalog.glue", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.glue.catalog-impl",
            "org.apache.iceberg.aws.glue.GlueCatalog") \
    .config("spark.sql.catalog.glue.warehouse", "s3://my-bucket/warehouse") \
    .getOrCreate()
```

## Hive Metastore Catalog

```python
spark = SparkSession.builder \
    .config("spark.sql.catalog.hive_cat", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.hive_cat.type", "hive") \
    .config("spark.sql.catalog.hive_cat.uri", "thrift://metastore:9083") \
    .getOrCreate()
```

## Nessie Catalog (Git-like versioning)

```python
spark = SparkSession.builder \
    .config("spark.sql.catalog.nessie", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.nessie.catalog-impl",
            "org.apache.iceberg.nessie.NessieCatalog") \
    .config("spark.sql.catalog.nessie.uri", "http://nessie:19120/api/v2") \
    .config("spark.sql.catalog.nessie.ref", "main") \
    .config("spark.sql.catalog.nessie.warehouse", "s3://my-bucket/warehouse") \
    .getOrCreate()
```

## Decision Guide

| Requirement | Recommended Catalog |
|-------------|-------------------|
| Production multi-engine access | REST (Polaris) |
| AWS-native, minimal infrastructure | Glue |
| Existing Hive ecosystem | Hive Metastore |
| Git-like branching for data | Nessie |
| Simple self-hosted, single DB | JDBC |
| Local development/testing | Hadoop (filesystem) |

## Common Mistakes

### Wrong

Using Hadoop catalog in production — it relies on file system renames for atomic commits, which are **not atomic on S3/GCS**.

### Correct

Use REST, Hive, Glue, or JDBC catalogs for production. These provide true atomic metadata updates through database transactions or API calls.

## Related

- [Table Format](../concepts/table-format.md) — metadata structure the catalog points to
- [Spark Integration](../patterns/spark-integration.md) — catalog config in Spark
