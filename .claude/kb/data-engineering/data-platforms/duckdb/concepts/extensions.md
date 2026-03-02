# DuckDB Extensions

> **Purpose**: Modular extension system for cloud storage, geospatial, foreign databases, and additional formats
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

DuckDB uses a modular extension system to keep the core engine lightweight while providing rich functionality through installable modules. Extensions can add file formats, data types, functions, and foreign database connectors. Core extensions support autoloading -- DuckDB automatically installs and loads them when their functionality is first used in a query.

## The Pattern

```sql
-- Manual install and load
install httpfs;
load httpfs;

-- Autoloading (core extensions only): just use the functionality
select * from read_parquet('s3://bucket/data.parquet');
-- DuckDB auto-installs and loads httpfs when it sees s3:// prefix

-- Check installed extensions
select * from duckdb_extensions() where installed;

-- Update extensions to latest version
update extensions;

-- Install from a specific repository
install spatial from core;

-- Force reinstall
force install httpfs;
```

## Core Extensions

| Extension | Purpose | Autoload |
|-----------|---------|----------|
| `parquet` | Parquet file read/write | Yes |
| `json` | JSON/NDJSON file read/write | Yes |
| `httpfs` | HTTP/S3/GCS/Azure remote file access | Yes |
| `aws` | AWS credential management (profiles, env vars) | Yes |
| `azure` | Azure Blob Storage credential management | Yes |
| `icu` | International Components for Unicode (collation, time zones) | Yes |
| `fts` | Full-text search indexes | Yes |
| `tpch` | TPC-H benchmark data generator | No |
| `tpcds` | TPC-DS benchmark data generator | No |

## Database Scanner Extensions

| Extension | Purpose | Usage |
|-----------|---------|-------|
| `postgres` | Read/write PostgreSQL tables | `ATTACH 'postgres:...' AS pg` |
| `mysql` | Read/write MySQL tables | `ATTACH 'mysql:...' AS my` |
| `sqlite` | Read/write SQLite files | `ATTACH 'sqlite:file.db' AS sq` |

```sql
-- Attach a PostgreSQL database and query it
install postgres;
load postgres;
attach 'dbname=mydb user=admin host=localhost' as pg (type postgres);
select * from pg.public.customers limit 10;

-- Attach SQLite file
install sqlite;
load sqlite;
attach 'legacy.sqlite' as legacy (type sqlite);
select * from legacy.main.orders;
```

## Data Lake Extensions

| Extension | Purpose | Function |
|-----------|---------|----------|
| `iceberg` | Apache Iceberg table scanning | `iceberg_scan()` |
| `delta` | Delta Lake table scanning | `delta_scan()` |

## Specialized Extensions

| Extension | Purpose |
|-----------|---------|
| `spatial` | Geospatial types (GEOMETRY, POINT) and functions (ST_*), Excel reader |
| `excel` | Alias for spatial extension's Excel reading capability |
| `vss` | Vector Similarity Search for embeddings |
| `inet` | IP address types and functions |
| `jemalloc` | Alternative memory allocator (Linux) |

## Common Mistakes

### Wrong

```sql
-- Trying to use S3 without any extension setup
select * from read_parquet('s3://my-bucket/data.parquet');
-- This actually works now with autoloading! But explicit is safer in scripts:
```

### Correct

```sql
-- Explicit in production scripts for clarity and error handling
install httpfs;
load httpfs;
set s3_region = 'us-east-1';
set s3_access_key_id = 'AKIA...';
set s3_secret_access_key = 'secret';

-- Or use the Secrets Manager (recommended)
create secret my_s3 (type s3, region 'us-east-1', key_id 'AKIA...', secret 'secret');
select * from read_parquet('s3://my-bucket/data.parquet');
```

## Related

- [data-import-export](../concepts/data-import-export.md)
- [remote-files](../patterns/remote-files.md)
- [architecture](../concepts/architecture.md)
