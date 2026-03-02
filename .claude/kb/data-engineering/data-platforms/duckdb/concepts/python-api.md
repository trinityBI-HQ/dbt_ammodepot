# DuckDB Python API

> **Purpose**: Python integration with connection management, Pandas/Polars interop, Arrow zero-copy, and Jupyter workflows
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

DuckDB's Python package (`pip install duckdb`) provides a full-featured API for running SQL queries, converting results to Pandas DataFrames or Arrow tables, and querying Python objects (DataFrames, lists) directly with SQL via replacement scans. The in-process architecture means zero serialization overhead between Python and DuckDB when using Apache Arrow as the interchange format.

## The Pattern

```python
import duckdb

# Connect (in-memory or persistent)
con = duckdb.connect()              # In-memory
con = duckdb.connect("analytics.db") # Persistent file

# Execute SQL and fetch results
result = con.sql("select 42 as answer")
result.show()                          # Pretty-print to console
result.fetchall()                      # List of tuples: [(42,)]
result.fetchone()                      # Single tuple: (42,)
result.fetchdf()                       # Pandas DataFrame
result.df()                            # Alias for fetchdf()
result.fetch_arrow_table()             # PyArrow Table (zero-copy)
result.fetchnumpy()                    # Dict of NumPy arrays
result.pl()                            # Polars DataFrame

# Module-level API (uses shared default connection)
duckdb.sql("select * from 'data.parquet'").df()
```

## Replacement Scans (Query Python Objects)

```python
import pandas as pd
import polars as pl

# Pandas DataFrame -- query directly by variable name
df = pd.DataFrame({"id": [1, 2, 3], "name": ["a", "b", "c"]})
duckdb.sql("select * from df where id > 1").show()

# Polars DataFrame -- same syntax
pl_df = pl.DataFrame({"x": [10, 20, 30], "y": [1.1, 2.2, 3.3]})
duckdb.sql("select x, y * 2 as y2 from pl_df").show()

# Python lists and dicts
duckdb.sql("select * from [1, 2, 3]").show()

# Arrow tables
import pyarrow as pa
arrow_table = pa.table({"col1": [1, 2], "col2": ["a", "b"]})
duckdb.sql("select * from arrow_table").show()
```

## Relation API

```python
# Build queries incrementally without SQL strings
con = duckdb.connect()
rel = con.read_parquet("sales.parquet")
result = (
    rel
    .filter("amount > 100")
    .aggregate("category, sum(amount) as total", "category")
    .order("total desc")
    .limit(10)
)
result.show()
result.df()  # Convert to Pandas at the end
```

## Quick Reference

| Method | Returns | Use Case |
|--------|---------|----------|
| `.fetchall()` | `list[tuple]` | Small results, row iteration |
| `.fetchone()` | `tuple` | Single row |
| `.fetchmany(n)` | `list[tuple]` | Batch fetching |
| `.fetchdf()` / `.df()` | `pd.DataFrame` | Pandas workflows |
| `.pl()` | `pl.DataFrame` | Polars workflows |
| `.fetch_arrow_table()` | `pa.Table` | Zero-copy Arrow |
| `.fetchnumpy()` | `dict[np.array]` | NumPy computation |
| `.show()` | `None` | Console display |
| `.describe()` | `DuckDBPyRelation` | Column statistics |

## Common Mistakes

### Wrong

```python
# Creating a new connection for every query (unnecessary overhead)
for file in parquet_files:
    con = duckdb.connect()
    result = con.sql(f"select count(*) from '{file}'")
    con.close()
```

### Correct

```python
# Reuse a single connection
con = duckdb.connect()
for file in parquet_files:
    result = con.sql(f"select count(*) from '{file}'")
    print(result.fetchone())
con.close()

# Or use context manager
with duckdb.connect() as con:
    con.sql("select 42").show()
```

## Thread Safety

- The `duckdb` module-level functions use a shared default connection (not thread-safe)
- For multi-threaded apps, create one `duckdb.connect()` per thread
- A single connection can execute queries in parallel internally (morsel-driven)

## Related

- [architecture](../concepts/architecture.md)
- [python-data-science](../patterns/python-data-science.md)
- [performance](../concepts/performance.md)
