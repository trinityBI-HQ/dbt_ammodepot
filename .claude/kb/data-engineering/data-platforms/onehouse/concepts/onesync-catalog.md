# OneSync Catalog Synchronization

> **Purpose**: Multi-catalog sync enabling data access from any query engine without data duplication
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

OneSync is Onehouse's multi-catalog synchronization service that automatically registers lakehouse tables in multiple data catalogs simultaneously. When data is written to lakehouse tables via OneFlow or any other process, OneSync triggers sync jobs to each configured catalog, handling schema evolution, deletions, and table management transparently. This enables teams to write data once and query it from Snowflake, Databricks, BigQuery, or any engine that reads from supported catalogs.

## The Pattern

```text
Lakehouse Tables (Hudi/Iceberg/Delta in S3/GCS)
                    |
                    v
            +---------------+
            |   OneSync     |
            | Catalog Sync  |
            +---------------+
           /    |     |      \
          v     v     v       v
+------+ +------+ +------+ +------+
|Snowfl| |Unity | |Google| | AWS  |
|ake   | |Catal.| |Data  | | Glue |
|Catal.| |      | |Catal.| |      |
+------+ +------+ +------+ +------+
   |        |        |        |
   v        v        v        v
Snowflake  Databricks BigQuery Athena/
SQL        SQL/Spark  SQL      Redshift
```

## Quick Reference

| Catalog | Engine Access | Format Used |
|---------|--------------|-------------|
| Snowflake Catalog | Snowflake SQL | Iceberg (via XTable) |
| Databricks Unity Catalog | Databricks SQL/Spark | Delta Lake or Iceberg |
| Google Data Catalog | BigQuery | Iceberg (BigLake) |
| AWS Glue Data Catalog | Athena, Redshift Spectrum, EMR | Hudi or Iceberg |
| Hive Metastore | Spark, Trino, Presto | Hudi, Iceberg, or Delta |

| Feature | Description |
|---------|-------------|
| Multi-select catalogs | Choose multiple catalogs per pipeline |
| Auto schema evolution | Schema changes propagate to all catalogs |
| Deletion handling | Table drops reflected across all catalogs |
| Partition sync | Partition metadata kept consistent |
| Zero data duplication | Single copy of data files, multiple catalog entries |

## Common Mistakes

### Wrong

```text
Copying data into each engine's native format separately:
- S3 Hudi tables for Spark
- Snowflake native tables via Snowpipe
- BigQuery native tables via Dataflow
```

### Correct

```text
Write data once to Hudi tables in cloud storage.
Configure OneSync to register in Snowflake, Unity, and
Google Data Catalog. Each engine reads the same physical
files through its native catalog interface. XTable
translates metadata as needed for format compatibility.
```

## Related

- [XTable Interoperability](../concepts/xtable-interoperability.md)
- [OneFlow Ingestion](../concepts/oneflow-ingestion.md)
- [Multi-Engine Query Pattern](../patterns/multi-engine-query.md)
