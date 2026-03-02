# Python Data Science with DuckDB

> **Purpose**: DuckDB as a high-performance SQL engine for data science: Pandas/Polars interop, Jupyter workflows, Arrow zero-copy
> **MCP Validated**: 2026-03-01

## When to Use

- Replacing slow Pandas operations with SQL on large DataFrames
- Running SQL on Parquet files without loading into memory first
- Jupyter notebook workflows that need fast aggregation/joins
- Combining SQL and Python in the same analysis pipeline
- Processing datasets too large for Pandas but too small for Spark

## Implementation

```python
import duckdb
import pandas as pd

# SQL directly on a Pandas DataFrame (zero-copy via Arrow)
orders = pd.DataFrame({
    "customer_id": [1, 2, 1, 3, 2],
    "amount": [100.0, 250.0, 75.0, 300.0, 125.0],
    "product": ["A", "B", "A", "C", "B"]
})

# DuckDB detects the Python variable name automatically
result = duckdb.sql("""
    select
        customer_id,
        count(*) as order_count,
        sum(amount) as total_spent,
        list(distinct product) as products
    from orders
    group by all
    order by total_spent desc
""").df()

print(result)
#    customer_id  order_count  total_spent products
# 0            2            2        375.0   [B]
# 1            3            1        300.0   [C]
# 2            1            2        175.0   [A]
```

## Polars Integration

```python
import polars as pl

# Read with DuckDB, return as Polars DataFrame
sales = duckdb.sql("""
    select product_id, sum(revenue) as total_revenue
    from 'sales_2025.parquet'
    group by all
    having total_revenue > 10000
    order by total_revenue desc
""").pl()

# Query a Polars DataFrame with SQL
customers_pl = pl.read_parquet("customers.parquet")
vip = duckdb.sql("""
    select * from customers_pl
    where lifetime_value > 5000
    order by lifetime_value desc
""").pl()
```

## Arrow Zero-Copy

```python
import pyarrow as pa
import pyarrow.parquet as pq

# Read Parquet to Arrow (zero-copy into DuckDB)
arrow_table = pq.read_table("large_dataset.parquet")
result = duckdb.sql("""
    select category, avg(price) as avg_price
    from arrow_table
    group by all
""").fetch_arrow_table()

# Arrow -> Pandas (also zero-copy)
df = result.to_pandas()
```

## Jupyter Notebook Workflow

```python
# Cell 1: Install and configure
# %pip install duckdb pandas matplotlib

# Cell 2: Load and explore
import duckdb
con = duckdb.connect()

# Use magic-like syntax with .show() for display
con.sql("from 'sales.parquet' limit 5").show()
con.sql("summarize select * from 'sales.parquet'").show()

# Cell 3: Analysis
monthly = con.sql("""
    select
        date_trunc('month', sale_date) as month,
        sum(revenue) as total_revenue,
        count(distinct customer_id) as unique_customers
    from 'sales.parquet'
    group by all
    order by month
""").df()

# Cell 4: Visualization with Pandas/Matplotlib
monthly.set_index("month")[["total_revenue"]].plot(kind="bar", figsize=(12, 4))
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `duckdb.default_connection` | Auto | Module-level shared connection |
| `pandas_analyze_sample` | `1000` | Rows sampled to infer Pandas types |

## Replacing Slow Pandas Operations

| Pandas (Slow on Large Data) | DuckDB SQL (Fast) |
|-----------------------------|-------------------|
| `df.groupby('a').agg({'b': 'sum'})` | `SELECT a, sum(b) FROM df GROUP BY ALL` |
| `df.merge(df2, on='id')` | `SELECT * FROM df JOIN df2 USING (id)` |
| `df[df.amount > 100]` | `SELECT * FROM df WHERE amount > 100` |
| `df.drop_duplicates('id')` | `SELECT DISTINCT ON (id) * FROM df` |
| `df.pivot_table(...)` | `PIVOT df ON col USING sum(val)` |
| `df.sort_values('a').head(10)` | `FROM df ORDER BY a LIMIT 10` |

## Example Usage

```python
# Complete analysis pipeline
import duckdb

con = duckdb.connect()

# Load, transform, and analyze in one flow
cohort_analysis = con.sql("""
    with customer_first_order as (
        select customer_id,
            min(date_trunc('month', order_date)) as cohort_month
        from 'orders.parquet'
        group by all
    ),
    monthly_activity as (
        select
            c.cohort_month,
            date_trunc('month', o.order_date) as activity_month,
            count(distinct o.customer_id) as active_customers
        from 'orders.parquet' o
        join customer_first_order c using (customer_id)
        group by all
    )
    select
        cohort_month,
        activity_month,
        datediff('month', cohort_month, activity_month) as months_since,
        active_customers
    from monthly_activity
    order by cohort_month, months_since
""").df()

print(cohort_analysis.head(20))
```

## See Also

- [python-api](../concepts/python-api.md)
- [local-analytics](../patterns/local-analytics.md)
- [performance-tuning](../patterns/performance-tuning.md)
