# Performance Tuning

> **Purpose**: Configuration tuning, query profiling, and optimization strategies for DuckDB workloads
> **MCP Validated**: 2026-03-01

## When to Use

- Queries running slower than expected on local datasets
- Processing larger-than-memory datasets (spilling to disk)
- Tuning DuckDB for production ETL pipelines
- Diagnosing bottlenecks in complex analytical queries
- Optimizing parallel reads across many files

## Implementation

```sql
-- Step 1: Understand the query plan
explain
select customer_id, sum(amount) as total
from 'orders.parquet'
where order_date >= '2025-01-01'
group by all;

-- Step 2: Profile with actual execution metrics
explain analyze
select customer_id, sum(amount) as total
from 'orders.parquet'
where order_date >= '2025-01-01'
group by all;

-- Step 3: JSON profiling for visualization
set enable_profiling = 'json';
set profiling_output = '/tmp/query_profile.json';
select customer_id, sum(amount) as total
from 'orders.parquet'
where order_date >= '2025-01-01'
group by all;
-- Open /tmp/query_profile.json in DuckDB profile viewer

-- Step 4: Tune based on findings
set memory_limit = '8GB';
set threads = 8;
set temp_directory = '/tmp/duckdb_spill';
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `memory_limit` | 80% RAM | Cap on memory usage |
| `threads` | CPU cores | Parallel threads |
| `temp_directory` | `{db}.tmp` | Spill-to-disk location |
| `preserve_insertion_order` | `true` | `false` = faster inserts |
| `enable_progress_bar` | `true` | Progress for long queries |
| `enable_profiling` | disabled | `json`, `query_tree`, `query_tree_optimizer` |

## Optimization Strategies

### Use Parquet over CSV

```sql
-- Slow: CSV requires full scan, no column pruning
select customer_id, sum(amount)
from read_csv('orders.csv') group by all;

-- Fast: Parquet has column pruning + predicate pushdown
select customer_id, sum(amount)
from read_parquet('orders.parquet') group by all;

-- Convert once, query many times
copy (select * from read_csv('data.csv')) to 'data.parquet' (format parquet);
```

### Partition for Predicate Pushdown

```sql
-- Write partitioned Parquet
copy orders to 'output/' (format parquet, partition_by (year, region));

-- Query with partition filters (DuckDB skips unneeded files)
select sum(amount) from read_parquet('output/**/*.parquet',
    hive_partitioning = true
) where year = 2025 and region = 'US';
```

### Parallel File Processing

```sql
-- Reading many files in parallel is automatic
select count(*) from read_parquet('data/*.parquet');

-- For CSV, parallel reading works across files (not within a single file)
select count(*) from read_csv(['a.csv', 'b.csv', 'c.csv', 'd.csv']);

-- Per-thread output for parallel writes
copy large_table to 'output/' (format parquet, per_thread_output true);
```

### Memory-Efficient Patterns

```sql
-- Limit memory for constrained environments
set memory_limit = '2GB';
set temp_directory = '/mnt/ssd/spill';

-- Streaming aggregation (no full materialization)
select approx_count_distinct(user_id) from 'huge_events.parquet';

-- Use USING SAMPLE for exploration instead of full scans
from 'huge_table.parquet' using sample 1% select *;
```

## Example Usage

```python
import duckdb
import time

con = duckdb.connect()

# Benchmark function
def benchmark(query, label=""):
    start = time.time()
    result = con.sql(query).fetchone()
    elapsed = time.time() - start
    print(f"{label}: {elapsed:.3f}s -> {result}")

# Compare formats
con.sql("copy (select * from range(10_000_000) t(id)) to '/tmp/bench.csv'")
con.sql("copy (select * from range(10_000_000) t(id)) to '/tmp/bench.parquet'")

benchmark("select count(*) from '/tmp/bench.csv'", "CSV")
benchmark("select count(*) from '/tmp/bench.parquet'", "Parquet")

# Tune for heavy workload
con.sql("set memory_limit = '4GB'")
con.sql("set threads = 4")

# Check current settings
con.sql("""
    select name, value, description
    from duckdb_settings()
    where name in ('memory_limit', 'threads', 'temp_directory')
""").show()
```

## Profiling Checklist

| Check | Command | Look For |
|-------|---------|----------|
| Query plan | `EXPLAIN` | Sequential scans, missing filters |
| Actual timing | `EXPLAIN ANALYZE` | Slow operators, skew |
| Memory pressure | `PRAGMA database_size` | Spill-to-disk activity |
| Thread utilization | Check `threads` setting | Under-utilized cores |
| File format | Check source format | CSV vs Parquet |
| Predicate pushdown | Check EXPLAIN for filters | Filters at scan level |

## See Also

- [performance](../concepts/performance.md)
- [data-import-export](../concepts/data-import-export.md)
- [remote-files](../patterns/remote-files.md)
