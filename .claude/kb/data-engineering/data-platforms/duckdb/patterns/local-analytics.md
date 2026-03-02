# Local Analytics with DuckDB

> **Purpose**: Using DuckDB for local data exploration, Parquet/CSV querying, data profiling, and ad-hoc analysis
> **MCP Validated**: 2026-03-01

## When to Use

- Exploring CSV or Parquet files without setting up a database server
- Quick data profiling on new datasets (row counts, distributions, nulls)
- Ad-hoc analysis that would otherwise require loading into a warehouse
- Prototyping SQL queries before deploying to a production warehouse

## Implementation

```sql
-- Start DuckDB CLI for interactive exploration
-- $ duckdb

-- Quick look at a file's schema and sample data
describe select * from 'sales_2025.parquet';
from 'sales_2025.parquet' limit 10;

-- Row count and basic stats
select count(*) as rows from 'sales_2025.parquet';
summarize select * from 'sales_2025.parquet';

-- Combine multiple CSV files with glob
select count(*) as rows, filename
from read_csv('logs/*.csv', filename = true)
group by all
order by all;

-- NULL analysis across all columns
select
    count(*) as total_rows,
    count(customer_id) as non_null_customer,
    count(*) - count(email) as null_emails,
    count(distinct product_id) as unique_products
from 'orders.parquet';

-- Distribution analysis
select product_category, count(*) as cnt,
    round(count(*) * 100.0 / sum(count(*)) over (), 2) as pct
from 'sales.parquet'
group by all
order by cnt desc;

-- Date range and freshness check
select
    min(created_at) as earliest,
    max(created_at) as latest,
    datediff('day', min(created_at), max(created_at)) as span_days
from 'events.parquet';
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `.mode` | `duckbox` | Output format: csv, json, table, markdown, line |
| `.maxrows` | `40` | Max rows displayed |
| `.timer on` | off | Show query execution time |
| `.width` | auto | Column display width |

## Example Usage

```python
import duckdb

# Profile a dataset in Python
con = duckdb.connect()

# Comprehensive profiling in one query
profile = con.sql("""
    select
        count(*) as row_count,
        count(distinct customer_id) as unique_customers,
        min(order_date) as min_date,
        max(order_date) as max_date,
        avg(total_amount) as avg_amount,
        median(total_amount) as median_amount,
        quantile_cont(total_amount, 0.95) as p95_amount,
        sum(case when total_amount is null then 1 else 0 end) as null_amounts
    from 'orders.parquet'
""").df()

print(profile.to_string())

# Quick CSV exploration with auto-detection
con.sql("""
    from read_csv('unknown_data.csv',
        auto_detect = true,
        sample_size = 10000
    ) limit 20
""").show()

# Export analysis results
con.sql("""
    copy (
        select product_category, count(*) as orders, sum(amount) as revenue
        from 'sales/*.parquet'
        group by all
        order by revenue desc
    ) to 'category_summary.csv' (header)
""")
```

## See Also

- [data-import-export](../concepts/data-import-export.md)
- [sql-dialect](../concepts/sql-dialect.md)
- [performance-tuning](../patterns/performance-tuning.md)
