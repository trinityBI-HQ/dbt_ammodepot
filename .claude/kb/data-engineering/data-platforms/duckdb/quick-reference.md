# DuckDB Quick Reference

> **MCP Validated**: 2026-03-01
> Fast lookup tables. For code examples, see linked files.

## Core Data Types

| Type | Example | Notes |
|------|---------|-------|
| `INTEGER` / `BIGINT` | `42` | Also: TINYINT, SMALLINT, HUGEINT |
| `DOUBLE` / `FLOAT` | `3.14` | IEEE 754 floating point |
| `DECIMAL(p,s)` | `DECIMAL(18,2)` | Exact numeric |
| `VARCHAR` | `'hello'` | Variable-length string (alias: TEXT, STRING) |
| `BOOLEAN` | `true` / `false` | Logical |
| `DATE` / `TIMESTAMP` | `DATE '2026-03-01'` | Also: TIMESTAMPTZ, TIME, INTERVAL |
| `BLOB` | `'\xAA'::BLOB` | Binary data |
| `LIST` | `[1, 2, 3]` | Ordered array of uniform type |
| `STRUCT` | `{'a': 1, 'b': 'x'}` | Named fields, heterogeneous types |
| `MAP` | `MAP {'k1': 'v1'}` | Key-value pairs, uniform key type |
| `UNION` | `union_value(s := 'hi')` | Tagged union of types |

## Friendly SQL Shortcuts

| Feature | Syntax | Equivalent |
|---------|--------|------------|
| GROUP BY ALL | `SELECT a, sum(b) FROM t GROUP BY ALL` | `GROUP BY a` |
| ORDER BY ALL | `SELECT a, b FROM t ORDER BY ALL` | `ORDER BY a, b` |
| EXCLUDE | `SELECT * EXCLUDE (col1) FROM t` | All columns except col1 |
| REPLACE | `SELECT * REPLACE (col1 * 2 AS col1)` | Override column expression |
| COLUMNS | `SELECT COLUMNS('price.*') FROM t` | Regex column selection |
| FROM-first | `FROM t SELECT a, b WHERE a > 1` | SELECT last |
| QUALIFY | `SELECT *, row_number() OVER (PARTITION BY a ORDER BY b) AS rn FROM t QUALIFY rn = 1` | Filter window results |

## File Reading Functions

| Function | Usage |
|----------|-------|
| `read_parquet('f.parquet')` | Read Parquet file(s) |
| `read_csv('f.csv')` | Read CSV with auto-detect |
| `read_json('f.json')` | Read JSON / NDJSON |
| `read_parquet('*.parquet')` | Glob multiple files |
| `read_parquet('s3://bucket/path/')` | Remote via httpfs |
| `read_xlsx('f.xlsx')` | Read Excel (spatial ext) |

## CLI Commands

| Command | Purpose |
|---------|---------|
| `duckdb` | Open in-memory session |
| `duckdb my.db` | Open/create persistent database |
| `.open file.db` | Switch database |
| `.mode` | Set output mode (csv, json, table) |
| `.timer on` | Show query timing |
| `.maxrows N` | Limit displayed rows |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Quick CSV/Parquet exploration | DuckDB CLI or Python |
| Local dbt development | dbt-duckdb adapter |
| ETL: format conversion | COPY TO / read_* functions |
| SQL on DataFrames | `duckdb.sql("SELECT * FROM df")` |
| Query S3/GCS Parquet | httpfs extension + read_parquet |
| Geospatial analysis | spatial extension |
| Query Postgres tables | postgres extension |

## Common Pitfalls

| Avoid | Do Instead |
|-------|------------|
| Loading huge CSV without schema | Use `read_csv('f.csv', columns={...})` |
| Forgetting httpfs for S3 | `INSTALL httpfs; LOAD httpfs;` |
| Using `fetchall()` for large results | Use `fetchdf()` or `fetch_arrow_table()` |
| In-memory DB for persistent data | Use `duckdb.connect('file.db')` |
| Ignoring memory_limit on laptops | `SET memory_limit = '4GB'` |

## Related

| Topic | Path |
|-------|------|
| Architecture | `concepts/architecture.md` |
| SQL Dialect | `concepts/sql-dialect.md` |
| Python API | `concepts/python-api.md` |
| Full Index | `index.md` |
