# Table Optimization Pattern

> **Purpose**: Configure compaction, clustering, and cleaning for optimal query performance and storage efficiency
> **MCP Validated**: 2026-03-01

## When to Use

- Query performance degrading on large lakehouse tables due to small files
- Merge-on-Read tables accumulating log files that slow read queries
- Storage costs growing from expired snapshots and old file versions
- Queries scanning too much data because layout does not match query patterns
- Managing hundreds of tables where manual optimization is impractical

## Implementation

```text
Table Optimization Strategy
============================

1. ASSESS TABLE TYPE AND WORKLOAD

   Copy-on-Write (CoW):
     - Better for read-heavy workloads
     - Writes are slower (full file rewrite on update)
     - No compaction needed
     - Focus on: Clustering + Cleaning

   Merge-on-Read (MoR):
     - Better for write-heavy workloads (CDC, streaming)
     - Writes are fast (append to log files)
     - Reads slower without compaction
     - Focus on: Compaction + Clustering + Cleaning

2. CONFIGURE COMPACTION (MoR tables only)

   Purpose: Merge log files into base Parquet files
   Trigger: Time-based or commit-based

   Recommended settings by workload:
   +---------------------+------------------+---------------------+
   | Workload            | Frequency        | Bytes per Compact   |
   +---------------------+------------------+---------------------+
   | High-throughput CDC | Every 15-30 min  | 256MB               |
   | Moderate streaming  | Every 1-2 hours  | 512MB               |
   | Low-frequency batch | Every 4-6 hours  | 512MB               |
   +---------------------+------------------+---------------------+

3. CONFIGURE CLUSTERING

   Purpose: Reorganize data files by key columns
   Mode: Incremental (only new data since last clustering)

   Key selection guidelines:
   +---------------------+---------------------------+
   | Query Pattern       | Clustering Key            |
   +---------------------+---------------------------+
   | Time-range queries  | Date/timestamp column     |
   | Regional filtering  | Region/country column     |
   | Entity lookups      | Customer_id, product_id   |
   | Multi-column filter | Compound key (date+region)|
   +---------------------+---------------------------+

   Recommended frequency:
   - High-churn tables: Every 2-4 hours
   - Moderate tables: Daily
   - Low-churn tables: Weekly

4. CONFIGURE CLEANING

   Purpose: Remove files beyond retention policy

   Recommended retention windows:
   +---------------------+------------------+
   | Use Case            | Retention        |
   +---------------------+------------------+
   | Time-travel needed  | 72-168 hours     |
   | Audit compliance    | 30+ days         |
   | Cost-sensitive      | 24-48 hours      |
   | Default             | 72 hours         |
   +---------------------+------------------+

   Cleaning frequency: Daily (minimum)

5. MONITOR WITH LAKEVIEW

   Key metrics to watch:
   - File count per partition (target: < 1000)
   - Average file size (target: 128MB-512MB)
   - Compaction backlog (target: < 5 pending)
   - Data skew ratio (target: < 3:1)
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `table_type` | `MERGE_ON_READ` | CoW or MoR based on read/write ratio |
| `compaction_trigger` | `time` | `time` or `commits` based trigger |
| `compaction_interval` | `30 min` | Time between compaction runs |
| `clustering_keys` | `[]` | Columns matching primary query patterns |
| `clustering_frequency` | `daily` | How often to cluster new data |
| `cleaning_retention_hours` | `72` | Hours to keep old file versions |
| `cleaning_frequency` | `daily` | How often to purge expired files |
| `target_file_size_mb` | `256` | Desired output file size |

## Example Usage

```text
Scenario: E-commerce Sales Table Optimization
==============================================

Table: sales_events (MoR, CDC from PostgreSQL)
Write rate: ~50K records/hour
Primary queries: Filter by order_date and store_id
Retention requirement: 7-day time travel

Optimization Config:
  compaction:
    trigger: time
    interval: 30 minutes
    target_file_size: 256MB

  clustering:
    keys: [order_date, store_id]
    strategy: linear
    frequency: every 4 hours

  cleaning:
    retention: 168 hours (7 days)
    frequency: daily

Result:
  - Read queries 5-10x faster (predicate pushdown on clustered keys)
  - Storage reduced 30% (cleaning removes old versions)
  - Write latency unchanged (compaction runs asynchronously)
```

## See Also

- [Table Optimizer](../concepts/table-optimizer.md)
- [Compute Runtime](../concepts/compute-runtime.md)
- [LakeView Observability](../concepts/lakeview-observability.md)
