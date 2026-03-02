# Data Import and Export

> **Purpose**: Reading and writing Parquet, CSV, JSON, Excel, Arrow, Iceberg, and Delta Lake from local and remote sources
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

DuckDB natively reads and writes multiple file formats without requiring data to be loaded into tables first. Functions like `read_parquet()`, `read_csv()`, and `read_json()` allow direct SQL queries on files. The `COPY` statement handles bulk import/export. Glob patterns match multiple files, and the httpfs extension enables reading from S3, GCS, and Azure Blob Storage.

## The Pattern

```sql
-- Query files directly (no CREATE TABLE needed)
select * from 'sales.parquet';
select * from 'data.csv';
select * from 'events.json';

-- Explicit reader functions with options
select * from read_csv('data.csv', header = true, delim = ',');
select * from read_parquet('warehouse/*.parquet', filename = true);
select * from read_json('events.ndjson', format = 'newline_delimited');

-- Glob patterns for multiple files
select * from read_parquet('data/year=*/month=*/*.parquet');
select * from read_csv(['file1.csv', 'file2.csv', 'file3.csv']);

-- COPY FROM: bulk import into existing table
copy orders from 'orders.csv' (header true, delimiter ',');
copy events from 'events.parquet' (format parquet);
copy logs from 'logs.json' (format json);

-- COPY TO: export query results
copy orders to 'output.parquet' (format parquet);
copy (select * from orders where year = 2025) to 'orders_2025.csv' (header, delimiter ',');

-- Partitioned Parquet export (Hive-style)
copy orders to 'output/' (format parquet, partition_by (year, month));
```

## Quick Reference

| Format | Read Function | Auto-Detect | COPY Support |
|--------|---------------|-------------|--------------|
| Parquet | `read_parquet()` | Schema from metadata | Yes |
| CSV | `read_csv()` | Delimiter, types, header | Yes |
| JSON / NDJSON | `read_json()` | Schema from sample | Yes |
| Excel | `read_xlsx()` | Requires spatial ext | No |
| Arrow IPC | `read_arrow()` | Via Arrow library | No |
| Iceberg | `iceberg_scan()` | Requires iceberg ext | No |
| Delta Lake | `delta_scan()` | Requires delta ext | No |

## File Reading Options

| Option | Applies To | Description |
|--------|-----------|-------------|
| `filename = true` | All readers | Add source filename column |
| `hive_partitioning = true` | Parquet, CSV | Parse Hive partition keys |
| `union_by_name = true` | All readers | Merge schemas across files |
| `columns = {...}` | CSV | Explicit column types |
| `header = true` | CSV | First row is header |
| `auto_detect = true` | CSV, JSON | Auto-detect schema |
| `compression = 'gzip'` | CSV, JSON | Read compressed files |

## Common Mistakes

### Wrong

```sql
-- Creating a table just to query a file once
create table tmp as select * from read_parquet('data.parquet');
select count(*) from tmp;
drop table tmp;
```

### Correct

```sql
-- Query the file directly
select count(*) from 'data.parquet';

-- Or use a view for repeated access
create view sales as select * from read_parquet('sales/*.parquet');
```

## Iceberg and Delta Lake

```sql
-- Apache Iceberg (requires iceberg extension)
install iceberg;
load iceberg;
select * from iceberg_scan('s3://bucket/warehouse/db/table');

-- Delta Lake (requires delta extension)
install delta;
load delta;
select * from delta_scan('s3://bucket/delta-table/');
```

## Related

- [extensions](../concepts/extensions.md)
- [etl-processing](../patterns/etl-processing.md)
- [remote-files](../patterns/remote-files.md)
