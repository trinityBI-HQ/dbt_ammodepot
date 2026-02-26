# Partitions

> **Purpose**: Reduce data scans with partition pruning and projection
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Partitioning divides table data into segments stored in separate S3 prefixes. When queries filter on partition keys, Athena skips irrelevant partitions entirely. Proper partitioning is the second-biggest cost optimization after choosing columnar formats.

## Hive-Style Partitions

Standard partitioning with explicit key=value S3 paths:

```
s3://lake/orders/year=2025/month=01/day=15/data.parquet
s3://lake/orders/year=2025/month=01/day=16/data.parquet
s3://lake/orders/year=2025/month=02/day=01/data.parquet
```

```sql
CREATE EXTERNAL TABLE orders (
    order_id STRING, customer_id STRING, amount DECIMAL(10,2)
)
PARTITIONED BY (year STRING, month STRING, day STRING)
STORED AS PARQUET
LOCATION 's3://lake/orders/';

-- Register all partitions from S3
MSCK REPAIR TABLE orders;

-- Or register one partition
ALTER TABLE orders ADD
    PARTITION (year='2025', month='02', day='01')
    LOCATION 's3://lake/orders/year=2025/month=02/day=01/';
```

## Partition Projection

Projection tells Athena the partition pattern so it can compute partitions mathematically instead of reading them from the Glue Catalog. This eliminates `MSCK REPAIR` and speeds up query planning.

```sql
CREATE EXTERNAL TABLE events (
    event_id STRING, user_id STRING, payload STRING
)
PARTITIONED BY (dt STRING, hour INT)
STORED AS PARQUET
LOCATION 's3://lake/events/'
TBLPROPERTIES (
    'projection.enabled'        = 'true',
    'projection.dt.type'        = 'date',
    'projection.dt.range'       = '2023-01-01,NOW',
    'projection.dt.format'      = 'yyyy-MM-dd',
    'projection.dt.interval'    = '1',
    'projection.dt.interval.unit' = 'DAYS',
    'projection.hour.type'      = 'integer',
    'projection.hour.range'     = '0,23',
    'storage.location.template' = 's3://lake/events/dt=${dt}/hour=${hour}/'
);
-- No MSCK REPAIR needed! New partitions are auto-discovered.
```

## Projection Types

| Type | Use Case | Example |
|------|----------|---------|
| `date` | Time-series data | `range='2023-01-01,NOW'` |
| `integer` | Numeric ranges | `range='0,23'` |
| `enum` | Fixed set of values | `values='us,eu,ap'` |
| `injected` | Pass-through (no validation) | For non-standard patterns |

## When to Use Projection vs Catalog

| Factor | Partition Projection | Catalog Partitions |
|--------|---------------------|--------------------|
| New partition speed | Instant (computed) | Requires MSCK/ALTER/crawler |
| Pattern requirement | Must be predictable | Any pattern |
| Partition count | Unlimited | 10M per table limit |
| Cross-service use | Athena only | Athena, Glue, EMR, Redshift |
| Maintenance | Zero | Must register new partitions |

**Use projection when:** partition keys follow a predictable pattern (dates, hours, regions).
**Use catalog when:** partitions are unpredictable or shared with Glue/EMR.

## Partition Pruning in Queries

```sql
-- Good: Athena reads only 1 day (1 partition)
SELECT * FROM events WHERE dt = '2025-06-15' AND hour = 10;

-- Good: Range scan reads ~30 partitions
SELECT * FROM events WHERE dt BETWEEN '2025-06-01' AND '2025-06-30';

-- Bad: Function on partition key prevents pruning
SELECT * FROM events WHERE YEAR(dt) = 2025;  -- Full scan!

-- Bad: Missing partition key = full scan
SELECT * FROM events WHERE user_id = 'u-123';  -- Scans all partitions
```

## Choosing Partition Keys

| Data Pattern | Partition Keys | Granularity |
|-------------|---------------|-------------|
| Daily batch loads | `year/month/day` | ~365 partitions/year |
| Hourly streaming | `dt/hour` | ~8,760 partitions/year |
| Multi-region | `region/year/month` | Moderate |
| High-volume events | `dt/hour/source` | Fine-grained |

**Rules of thumb:**
- Target 100 MB - 1 GB of data per partition
- Avoid too many partitions with tiny files (slow listing)
- Avoid too few partitions with huge files (no pruning benefit)
- Maximum 3-4 levels of partition nesting

## Common Mistakes

### Wrong

```sql
-- Over-partitioning: 1000s of tiny partitions
PARTITIONED BY (year, month, day, hour, minute, source, region)
-- Each partition has only a few KB of data
```

### Correct

```sql
-- Right-sized partitions: ~100 MB each
PARTITIONED BY (year, month, day)
-- Or use dt (date string) for simplicity
PARTITIONED BY (dt)
```

## Related

- [Tables and Views](../concepts/tables-views.md)
- [Query Optimization](../patterns/query-optimization.md)
