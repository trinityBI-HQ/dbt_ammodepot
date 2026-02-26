# Apache Iceberg Knowledge Base

> **Purpose**: Open table format for huge analytic datasets — ACID transactions, schema evolution, hidden partitioning
> **Version**: 1.10.x (Format Spec v3 ratified 2025)
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/table-format.md](concepts/table-format.md) | Metadata layers, manifests, snapshots architecture |
| [concepts/catalog.md](concepts/catalog.md) | Catalog types (REST, Hive, Glue, Nessie, Polaris) |
| [concepts/schema-evolution.md](concepts/schema-evolution.md) | Add/drop/rename/reorder columns without rewrite |
| [concepts/partitioning.md](concepts/partitioning.md) | Hidden partitioning, transforms, partition evolution |
| [concepts/snapshots-time-travel.md](concepts/snapshots-time-travel.md) | Snapshot isolation, time travel, rollback, branching/tagging |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/spark-integration.md](patterns/spark-integration.md) | Reading, writing, DDL, MERGE INTO with Spark |
| [patterns/table-maintenance.md](patterns/table-maintenance.md) | Compaction, expire snapshots, rewrite manifests |
| [patterns/migration-from-hive.md](patterns/migration-from-hive.md) | In-place and snapshot migration from Hive tables |
| [patterns/performance-tuning.md](patterns/performance-tuning.md) | Z-order, file pruning, predicate pushdown, sorted writes |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

Apache Iceberg is an **open table format** designed to solve the limitations of Hive-style table layouts. It tracks every file in a table through a metadata tree (metadata files → manifest lists → manifest files → data files).

| Concept | Description |
|---------|-------------|
| **Snapshot** | Immutable state of a table at a point in time |
| **Manifest List** | List of manifest files in a snapshot |
| **Manifest File** | Tracks data files with column-level stats (min/max/null counts) |
| **Hidden Partitioning** | Partition transforms derived from columns — users query columns, not partitions |
| **Schema Evolution** | Add, drop, rename, reorder, widen columns without rewriting data |
| **Partition Evolution** | Change partition strategy without rewriting existing data |
| **Catalog** | Service that tracks current metadata pointer for each table |
| **ACID Transactions** | Serializable isolation via optimistic concurrency on metadata |
| **Deletion Vectors** | Binary bitmaps marking deleted rows without rewriting files (v3, 1.8.0) |
| **Variant Type** | Semi-structured data type for JSON-like data (v3, 1.9.0) |
| **Geospatial Types** | Native geometry/geography types (v3, 1.9.0) |

### Core Principle: File-Level Tracking

Unlike Hive (which uses directory listings), Iceberg tracks **every data file explicitly** in manifests. This eliminates expensive file listing operations and enables:
- Correct query planning from metadata alone
- Column-level min/max stats for file pruning
- Atomic commits via metadata pointer swap

---

## Architecture

```text
Catalog (REST/Hive/Glue/Nessie)
  └── Current metadata pointer
        └── Metadata File (v2.metadata.json)
              ├── Schema (current + history)
              ├── Partition Spec (current + history)
              ├── Sort Order
              └── Snapshot List
                    └── Manifest List (snap-*.avro)
                          └── Manifest Files (*.avro)
                                └── Data Files (*.parquet)
                                      └── Delete Files (*.parquet)
```

Each snapshot points to a complete set of manifests. Snapshots share manifests and data files — only changed manifests are rewritten, making commits O(changed files) not O(total files).

## Release History

| Version | Date | Key Features |
|---------|------|-------------|
| **1.8.0** | Feb 2025 | Deletion vectors (binary bitmaps), default column values, row-level lineage |
| **1.9.0** | Apr 2025 | `variant` type, geospatial types, nanosecond timestamps |
| **1.10.0** | Sep 2025 | v3 spec stability, multi-argument partition transforms |
| **Format Spec v3** | 2025 | Deletion vectors, variant type, nanosecond timestamps, default values, multi-argument transforms, row lineage |
| **Apache Polaris** | Incubating | REST catalog implementation with Delta Lake support, PostgreSQL persistence |
| **v4 spec** | Early design | Focused on indexability and cache-friendliness |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/table-format.md, concepts/partitioning.md |
| **Intermediate** | concepts/schema-evolution.md, concepts/catalog.md, patterns/spark-integration.md |
| **Advanced** | concepts/snapshots-time-travel.md, patterns/performance-tuning.md, patterns/table-maintenance.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| spark-specialist | patterns/spark-integration.md | Read/write Iceberg with Spark |
| spark-performance-analyzer | patterns/performance-tuning.md | Optimize Iceberg query performance |
| medallion-architect | patterns/migration-from-hive.md | Design lakehouse with Iceberg |
| lakeflow-architect | patterns/table-maintenance.md | DLT pipelines with Iceberg |

---

## When to Use Iceberg

| Scenario | Iceberg | Delta Lake | Hudi |
|----------|:-------:|:----------:|:----:|
| Multi-engine (Spark + Trino + Flink) | Best | Fair | Fair |
| Schema/partition evolution | Best | Good | Fair |
| Open standard (no vendor lock-in) | Best | Good | Good |
| Spark-only ecosystem | Good | Best | Good |
| Near-real-time upserts | Good | Good | Best |
| Databricks-native integration | Fair | Best | Poor |
| Time travel & branching | Best | Good | Fair |
| Community & ecosystem momentum | Best | Good | Fair |

**Rule of thumb**: Choose Iceberg for multi-engine, open-format lakehouse architectures. Choose Delta Lake if deeply invested in Databricks.
