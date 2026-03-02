# Table Optimizer

> **Purpose**: Automated table services -- compaction, clustering, and cleaning -- for Hudi, Iceberg, and Delta Lake tables
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

The Onehouse Table Optimizer is a managed service that automatically executes table maintenance operations across Apache Hudi, Apache Iceberg, and Delta Lake tables. It handles three core operations: compaction (merging log files into base files for Merge-on-Read tables), clustering (reorganizing data layout by specified key columns for faster queries), and cleaning (removing files beyond retention policies). The optimizer runs on OCR serverless compute and follows a "set it and forget it" model.

## The Pattern

```text
Table Optimizer Services
========================

1. COMPACTION (Merge-on-Read tables)
   Log files --> Merged base Parquet files
   Config: frequency, bytes-per-compaction threshold
   Result: Improved read performance on MoR tables

2. CLUSTERING (All table types)
   Small/scattered files --> Reorganized by clustering keys
   Config: clustering keys, layout strategy, frequency
   Result: Better data locality, faster predicate pushdown

3. CLEANING (All table types)
   Expired snapshots/files --> Removed beyond retention
   Config: frequency, retention window (hours/days)
   Result: Reduced storage costs, cleaner metadata

Execution Flow:
+-----------+     +-----------+     +-----------+
| Schedule  |---->| OCR Spark |---->| Optimized |
| Trigger   |     | Cluster   |     | Tables    |
+-----------+     +-----------+     +-----------+
     ^                                    |
     |            +-----------+           |
     +------------|  LakeView |<----------+
                  |  Metrics  |
                  +-----------+
```

## Quick Reference

| Operation | Table Formats | When to Use |
|-----------|--------------|-------------|
| Compaction | Hudi (MoR), Iceberg, Delta | High write throughput with log files accumulating |
| Clustering | Hudi, Iceberg, Delta | Queries filter on specific columns frequently |
| Cleaning | Hudi, Iceberg, Delta | Storage costs growing, old snapshots unnecessary |

| Config Parameter | Description | Typical Value |
|-----------------|-------------|---------------|
| Compaction frequency | How often to run compaction | Every N commits or time-based |
| Bytes per compaction | Size threshold per compaction job | 128MB - 512MB |
| Clustering keys | Columns to organize data by | Date, region, or primary filter columns |
| Clustering frequency | How often to re-cluster new data | Hourly to daily |
| Retention window | Time to keep old file versions | 24-168 hours |
| Cleaning frequency | How often to purge expired files | Daily |

## Common Mistakes

### Wrong

```text
Running clustering on the entire table every time.
Setting compaction to run on every single commit.
Skipping cleaning and letting storage costs grow unbounded.
```

### Correct

```text
Onehouse runs clustering INCREMENTALLY -- only new data is
clustered, saving compute while maintaining query performance.
Set frequency-based compaction schedules aligned with write
throughput. Configure cleaning with appropriate retention
windows (e.g., 72 hours for time-travel needs).
```

## Related

- [Compute Runtime](../concepts/compute-runtime.md)
- [LakeView Observability](../concepts/lakeview-observability.md)
- [Table Optimization Pattern](../patterns/table-optimization.md)
