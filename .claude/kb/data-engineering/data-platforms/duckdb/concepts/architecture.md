# DuckDB Architecture

> **Purpose**: In-process OLAP engine with columnar storage, vectorized execution, and zero external dependencies
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

DuckDB is an in-process analytical database management system (OLAP). Unlike PostgreSQL or MySQL, it runs inside the host process -- no separate server, no client-server protocol, no network overhead. It stores data in a single file (or operates fully in-memory) and uses columnar storage with vectorized query execution for high analytical throughput.

## The Pattern

```python
import duckdb

# In-memory database (no file, data lost on close)
con = duckdb.connect()

# Persistent single-file database
con = duckdb.connect("analytics.db")

# Read-only access (multiple processes can read simultaneously)
con = duckdb.connect("analytics.db", read_only=True)

# Query files directly without loading
con.sql("SELECT count(*) FROM 'sales_2025.parquet'").show()

# Close when done (auto-closes with context manager)
con.close()
```

```bash
# CLI: in-memory
duckdb

# CLI: persistent file
duckdb analytics.db

# CLI: read-only
duckdb -readonly analytics.db
```

## Quick Reference

| Component | Description |
|-----------|-------------|
| **Parser** | PostgreSQL-compatible SQL parser with DuckDB extensions |
| **Planner/Optimizer** | Cost-based optimizer with join ordering, filter pushdown, CSE |
| **Execution Engine** | Vectorized pull-based pipeline with morsel-driven parallelism |
| **Storage** | Columnar format with row groups, compression, min/max zonemaps |
| **Buffer Manager** | Manages memory with configurable limits, spills to temp directory |
| **Catalog** | Manages schemas, tables, views, macros, sequences, types |
| **Transaction Manager** | ACID-compliant with MVCC (serializable isolation) |

## Key Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| In-process (embedded) | Zero deployment friction, no server management |
| Columnar storage | Column scans dominate OLAP; skip irrelevant columns |
| Vectorized execution | Process batches of ~2048 values using SIMD/CPU cache |
| Single-file database | Portable, easy backup (just copy the file) |
| Morsel-driven parallelism | Automatic thread scaling per query operator |
| Lazy-loading from disk | Only reads needed columns and row groups |

## Common Mistakes

### Wrong

```python
# Opening multiple write connections to same file (will lock/fail)
con1 = duckdb.connect("shared.db")
con2 = duckdb.connect("shared.db")  # Error: database is locked
```

### Correct

```python
# Single writer, multiple readers
writer = duckdb.connect("analytics.db")
reader = duckdb.connect("analytics.db", read_only=True)

# Or use in-memory for concurrent workloads
con = duckdb.connect()  # Each process gets its own in-memory DB
```

## Storage Model

DuckDB's persistent storage organizes data into **row groups** (approximately 122,880 rows each). Within each row group, data is stored column-by-column with lightweight compression (dictionary, RLE, bitpacking, constant, frame-of-reference). Each column segment maintains min/max **zonemaps** for automatic partition pruning during scans.

## Concurrency Model

- **Single writer**: Only one process can write to a database file at a time
- **Multiple readers**: Multiple processes can read concurrently in read-only mode
- **In-process threads**: Within a single connection, queries execute in parallel across CPU cores
- **ACID transactions**: Full serializable isolation via MVCC

## Related

- [sql-dialect](../concepts/sql-dialect.md)
- [performance](../concepts/performance.md)
- [local-analytics](../patterns/local-analytics.md)
