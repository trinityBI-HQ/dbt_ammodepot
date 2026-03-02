# ETL Processing with DuckDB

> **Purpose**: Using DuckDB as an ETL engine for format conversion, data transformation, and bulk loading pipelines
> **MCP Validated**: 2026-03-01

## When to Use

- Converting between file formats (CSV to Parquet, JSON to CSV, etc.)
- Transforming and cleaning data before loading into a warehouse
- Merging/deduplicating files from multiple sources
- Building lightweight ETL pipelines without Spark or Airflow
- Processing medium-scale data (GB to low-TB) on a single machine

## Implementation

```sql
-- Format conversion: CSV to Parquet with compression
copy (select * from read_csv('raw/*.csv', auto_detect = true))
to 'output/clean.parquet' (format parquet, compression zstd);

-- JSON to Parquet with schema enforcement
copy (
    select
        cast(id as integer) as id,
        name::varchar as name,
        cast(amount as decimal(18,2)) as amount,
        cast(created_at as timestamp) as created_at
    from read_json('events/*.ndjson')
)
to 'output/events.parquet' (format parquet);

-- Partitioned Parquet output (Hive-style directories)
copy (
    select *, year(order_date) as year, month(order_date) as month
    from 'orders.parquet'
)
to 'output/partitioned/' (format parquet, partition_by (year, month));

-- Merge multiple sources with deduplication
copy (
    with all_records as (
        select *, 'source_a' as origin from read_parquet('source_a/*.parquet')
        union all
        select *, 'source_b' as origin from read_parquet('source_b/*.parquet')
    ),
    deduped as (
        select *, row_number() over (
            partition by id order by updated_at desc
        ) as rn
        from all_records
        qualify rn = 1
    )
    select * exclude (rn) from deduped
)
to 'output/merged.parquet' (format parquet);
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `compression` | `snappy` | Parquet compression: zstd, gzip, snappy, none |
| `row_group_size` | `122880` | Rows per Parquet row group |
| `partition_by` | None | Columns for Hive-style partitioning |
| `overwrite_or_ignore` | `false` | Overwrite existing partitioned output |
| `per_thread_output` | `false` | One file per thread (parallel writes) |

## Example Usage

```python
import duckdb

con = duckdb.connect()

# Full ETL pipeline in Python
def run_etl():
    # Extract: read from multiple sources
    con.sql("""
        create or replace table staging as
        select
            id, name, email,
            cast(revenue as decimal(18,2)) as revenue,
            cast(signup_date as date) as signup_date
        from read_csv('incoming/customers_*.csv',
            auto_detect = true,
            ignore_errors = true
        )
    """)

    # Transform: clean and enrich
    con.sql("""
        create or replace table cleaned as
        select
            id,
            trim(lower(name)) as name,
            trim(lower(email)) as email,
            coalesce(revenue, 0) as revenue,
            signup_date,
            datediff('day', signup_date, current_date) as days_since_signup
        from staging
        where email is not null
          and email like '%@%'
    """)

    # Load: export to partitioned Parquet
    con.sql("""
        copy cleaned to 'output/customers/'
        (format parquet, partition_by (year(signup_date)),
         compression zstd)
    """)

    # Summary statistics
    stats = con.sql("""
        select count(*) as rows_processed,
            count(distinct id) as unique_customers,
            sum(revenue) as total_revenue
        from cleaned
    """).fetchone()

    print(f"Processed {stats[0]} rows, {stats[1]} customers, ${stats[2]:,.2f} revenue")

run_etl()
```

## Bulk Loading Patterns

```sql
-- Load CSV into persistent table with type coercion
create table raw_events as
select * from read_csv('events.csv',
    columns = {
        'event_id': 'INTEGER',
        'event_type': 'VARCHAR',
        'payload': 'JSON',
        'timestamp': 'TIMESTAMP'
    }
);

-- Append new data
insert into raw_events
select * from read_csv('events_new.csv',
    columns = {
        'event_id': 'INTEGER',
        'event_type': 'VARCHAR',
        'payload': 'JSON',
        'timestamp': 'TIMESTAMP'
    }
);

-- Upsert pattern (insert or replace)
insert or replace into customers
select * from read_parquet('customers_update.parquet');
```

## See Also

- [data-import-export](../concepts/data-import-export.md)
- [performance-tuning](../patterns/performance-tuning.md)
- [dbt-duckdb](../patterns/dbt-duckdb.md)
