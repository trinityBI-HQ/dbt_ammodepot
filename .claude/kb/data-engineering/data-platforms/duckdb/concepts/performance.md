# DuckDB Performance

> **Purpose**: Vectorized execution, memory management, indexing, query profiling, and optimization strategies
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

DuckDB achieves high analytical performance through vectorized query execution (processing batches of ~2048 values), automatic parallelism across CPU cores, columnar storage with compression, and a cost-based query optimizer. It can handle larger-than-memory workloads by spilling intermediate results to disk. Key tuning levers are `memory_limit`, `threads`, and `temp_directory`.

## The Pattern

```sql
-- Check current configuration
select current_setting('memory_limit');
select current_setting('threads');
select current_setting('temp_directory');

-- Configure memory and threads
set memory_limit = '8GB';       -- Default: 80% of system RAM
set threads = 4;                -- Default: number of CPU cores
set temp_directory = '/tmp/duckdb_spill';  -- For larger-than-memory

-- Profile a query
explain select count(*) from 'large.parquet' where amount > 100;
explain analyze select count(*) from 'large.parquet' where amount > 100;

-- Enable detailed profiling
set enable_profiling = 'json';
set profiling_output = '/tmp/profile.json';
select count(*) from 'large.parquet' where amount > 100;
```

## Quick Reference

| Setting | Default | Description |
|---------|---------|-------------|
| `memory_limit` | 80% of RAM | Max memory for query processing |
| `threads` | CPU core count | Parallel execution threads |
| `temp_directory` | `{db_file}.tmp` | Spill location for large queries |
| `enable_progress_bar` | `true` | Show progress for long queries |
| `preserve_insertion_order` | `true` | Set `false` for faster parallel inserts |

## Execution Pipeline

| Stage | Description |
|-------|-------------|
| **Parsing** | SQL text to AST |
| **Binding** | Resolve names, types, functions |
| **Optimization** | Filter pushdown, join reordering, CSE, predicate pushdown |
| **Physical Planning** | Choose operators (hash join vs merge join, parallel scan) |
| **Execution** | Vectorized pipeline with morsel-driven parallelism |

## Performance Strategies

| Strategy | When to Use | Implementation |
|----------|-------------|----------------|
| Filter pushdown | Always (automatic) | Optimizer pushes WHERE into scans |
| Parquet over CSV | Analytical workloads | Column pruning + predicate pushdown |
| Partitioned reads | Large datasets | Hive partitioning skips irrelevant files |
| Parallel CSV reading | Multi-file CSV | `read_csv(['a.csv', 'b.csv'])` |
| Preserve order off | Bulk inserts | `SET preserve_insertion_order = false` |
| ART indexes | Point lookups | `CREATE INDEX idx ON t(id)` |
| Projection pushdown | Wide tables | Select only needed columns |

## Common Mistakes

### Wrong

```sql
-- Reading CSV when Parquet is available (much slower)
select * from read_csv('huge_dataset.csv') where region = 'US';

-- Using too many threads on a shared machine
set threads = 128;  -- Causes contention if machine has 8 cores
```

### Correct

```sql
-- Use Parquet for analytical queries (predicate pushdown, column pruning)
select * from read_parquet('huge_dataset.parquet') where region = 'US';

-- Match threads to physical cores (not hyperthreads)
set threads = 8;

-- For network-heavy queries (S3), oversub threads
set threads = 32;  -- 2-5x CPU cores for I/O-bound work
```

## Memory Tuning Guidelines

| System RAM | Recommended memory_limit | threads | Use Case |
|-----------|-------------------------|---------|----------|
| 8 GB | 4-6 GB | 4 | Laptop, light analytics |
| 16 GB | 10-12 GB | 8 | Development workstation |
| 32 GB | 24 GB | 8-16 | Heavy ETL processing |
| 64+ GB | 48+ GB | 16+ | Production analytics |

## Larger-Than-Memory Queries

DuckDB automatically spills to disk when the configured `memory_limit` is exceeded. The temp directory is created at `{database_file}.tmp` by default. For in-memory databases, set `temp_directory` explicitly. The spilling mechanism supports hash joins, aggregations, sorts, and window functions.

```sql
-- Force a reasonable memory limit and set spill path
set memory_limit = '4GB';
set temp_directory = '/mnt/fast-ssd/duckdb_tmp';

-- Large aggregation will spill transparently
select customer_id, sum(amount) from 'huge_sales.parquet' group by all;
```

## Related

- [architecture](../concepts/architecture.md)
- [performance-tuning](../patterns/performance-tuning.md)
- [data-import-export](../concepts/data-import-export.md)
