# Apache Iceberg Knowledge Base

> **Purpose**: Open table format for huge analytic datasets -- ACID transactions, schema evolution, hidden partitioning
> **Version**: 1.10.x (Format Spec v3 ratified 2025) | **MCP Validated**: 2026-02-19

## Quick Navigation

| File | Purpose |
|------|---------|
| [concepts/table-format.md](concepts/table-format.md) | Metadata layers, manifests, snapshots architecture |
| [concepts/catalog.md](concepts/catalog.md) | Catalog types (REST, Hive, Glue, Nessie, Polaris) |
| [concepts/schema-evolution.md](concepts/schema-evolution.md) | Add/drop/rename/reorder columns without rewrite |
| [concepts/partitioning.md](concepts/partitioning.md) | Hidden partitioning, transforms, partition evolution |
| [concepts/snapshots-time-travel.md](concepts/snapshots-time-travel.md) | Snapshot isolation, time travel, rollback, branching/tagging |
| [patterns/spark-integration.md](patterns/spark-integration.md) | Reading, writing, DDL, MERGE INTO with Spark |
| [patterns/table-maintenance.md](patterns/table-maintenance.md) | Compaction, expire snapshots, rewrite manifests |
| [patterns/migration-from-hive.md](patterns/migration-from-hive.md) | In-place and snapshot migration from Hive tables |
| [patterns/performance-tuning.md](patterns/performance-tuning.md) | Z-order, file pruning, predicate pushdown, sorted writes |
| [quick-reference.md](quick-reference.md) | Fast lookup tables |

## Key Concepts

Iceberg tracks **every data file explicitly** in manifests (unlike Hive's directory listings), enabling correct query planning from metadata alone, column-level min/max stats for file pruning, and atomic commits via metadata pointer swap.

| Concept | Description |
|---------|-------------|
| **Snapshot** | Immutable state of a table at a point in time |
| **Manifest List/File** | Tracks data files with column-level stats (min/max/null counts) |
| **Hidden Partitioning** | Partition transforms derived from columns -- users query columns, not partitions |
| **Schema Evolution** | Add, drop, rename, reorder, widen columns without rewriting data |
| **Partition Evolution** | Change partition strategy without rewriting existing data |
| **Catalog** | Service that tracks current metadata pointer for each table |
| **ACID Transactions** | Serializable isolation via optimistic concurrency on metadata |
| **Deletion Vectors** | Binary bitmaps marking deleted rows without rewriting files (v3, 1.8.0) |
| **Variant Type** | Semi-structured data type for JSON-like data (v3, 1.9.0) |
| **Geospatial Types** | Native geometry/geography types (v3, 1.9.0) |

## Architecture

```text
Catalog (REST/Hive/Glue/Nessie)
  └── Current metadata pointer
        └── Metadata File (v2.metadata.json)
              ├── Schema, Partition Spec, Sort Order (current + history)
              └── Snapshot List
                    └── Manifest List (snap-*.avro)
                          └── Manifest Files (*.avro)
                                └── Data Files + Delete Files (*.parquet)
```

## Release History

| Version | Key Features |
|---------|-------------|
| **1.8.0** (Feb 2025) | Deletion vectors, default column values, row-level lineage |
| **1.9.0** (Apr 2025) | `variant` type, geospatial types, nanosecond timestamps |
| **1.10.0** (Sep 2025) | v3 spec stability, multi-argument partition transforms |
| **Format Spec v3** | Deletion vectors, variant, nanosecond timestamps, default values, row lineage |
| **Apache Polaris** | REST catalog (incubating), Delta Lake support, PostgreSQL persistence |

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/table-format.md, concepts/partitioning.md |
| **Intermediate** | concepts/schema-evolution.md, concepts/catalog.md, patterns/spark-integration.md |
| **Advanced** | concepts/snapshots-time-travel.md, patterns/performance-tuning.md, patterns/table-maintenance.md |

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| spark-specialist | patterns/spark-integration.md | Read/write Iceberg with Spark |
| spark-performance-analyzer | patterns/performance-tuning.md | Optimize Iceberg query performance |
| medallion-architect | patterns/migration-from-hive.md | Design lakehouse with Iceberg |
| lakeflow-architect | patterns/table-maintenance.md | DLT pipelines with Iceberg |

## When to Use Iceberg

| Scenario | Iceberg | Delta Lake | Hudi |
|----------|:-------:|:----------:|:----:|
| Multi-engine (Spark + Trino + Flink) | Best | Fair | Fair |
| Schema/partition evolution | Best | Good | Fair |
| Open standard (no vendor lock-in) | Best | Good | Good |
| Spark-only / Databricks-native | Good | Best | Good |
| Near-real-time upserts | Good | Good | Best |
| Time travel & branching | Best | Good | Fair |

**Rule of thumb**: Choose Iceberg for multi-engine, open-format lakehouse. Choose Delta Lake if deeply invested in Databricks.
