# DuckDB Knowledge Base

> **Purpose**: In-process analytical database for local analytics, ETL, and embeddable OLAP with multi-format data access
> **MCP Validated**: 2026-03-01

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/architecture.md](concepts/architecture.md) | In-process OLAP engine, columnar storage, vectorized execution |
| [concepts/sql-dialect.md](concepts/sql-dialect.md) | PostgreSQL-compatible SQL with DuckDB extensions |
| [concepts/data-import-export.md](concepts/data-import-export.md) | Reading/writing Parquet, CSV, JSON, Excel, Arrow, Iceberg, Delta |
| [concepts/extensions.md](concepts/extensions.md) | Extension system: INSTALL, LOAD, autoloading, core extensions |
| [concepts/python-api.md](concepts/python-api.md) | Python integration, Pandas/Polars, Arrow zero-copy |
| [concepts/performance.md](concepts/performance.md) | Vectorized execution, memory management, query profiling |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/local-analytics.md](patterns/local-analytics.md) | Querying Parquet/CSV files, data profiling, ad-hoc analysis |
| [patterns/dbt-duckdb.md](patterns/dbt-duckdb.md) | dbt-duckdb adapter configuration, plugins, local dev workflow |
| [patterns/etl-processing.md](patterns/etl-processing.md) | Multi-format ETL with SQL, COPY pipelines, bulk transforms |
| [patterns/python-data-science.md](patterns/python-data-science.md) | Pandas/Polars interop, Jupyter workflows, SQL on DataFrames |
| [patterns/remote-files.md](patterns/remote-files.md) | S3/GCS/Azure queries, httpfs, Iceberg/Delta scanning |
| [patterns/performance-tuning.md](patterns/performance-tuning.md) | Configuration tuning, EXPLAIN ANALYZE, parallel strategies |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables for data types, SQL syntax, CLI commands

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **In-Process** | Runs inside host process (Python, Node.js, R, Java) -- no server needed |
| **Columnar-Vectorized** | Processes data in columnar batches for high analytical throughput |
| **Single-File DB** | Entire database in one file, or fully in-memory -- zero dependencies |
| **Multi-Format Reader** | Natively reads Parquet, CSV, JSON, Excel, Arrow, Iceberg, Delta Lake |
| **Friendly SQL** | GROUP BY ALL, ORDER BY ALL, EXCLUDE/REPLACE, COLUMNS(), FROM-first |
| **Nested Types** | LIST, STRUCT, MAP, UNION for complex data modeling |
| **Extension System** | Modular extensions for cloud storage, geospatial, foreign databases |
| **Replacement Scans** | Query Pandas/Polars DataFrames directly with SQL (zero-copy via Arrow) |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/architecture.md, concepts/sql-dialect.md |
| **Intermediate** | concepts/data-import-export.md, patterns/local-analytics.md |
| **Advanced** | patterns/remote-files.md, patterns/performance-tuning.md |
| **dbt Users** | patterns/dbt-duckdb.md, patterns/etl-processing.md |
| **Data Science** | concepts/python-api.md, patterns/python-data-science.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| dbt-expert | patterns/dbt-duckdb.md | Local dbt development with DuckDB |
| python-developer | concepts/python-api.md, patterns/python-data-science.md | Python analytics workflows |
| data-engineer | patterns/etl-processing.md, patterns/remote-files.md | ETL pipeline development |
| codebase-explorer | patterns/local-analytics.md | Ad-hoc data exploration |
