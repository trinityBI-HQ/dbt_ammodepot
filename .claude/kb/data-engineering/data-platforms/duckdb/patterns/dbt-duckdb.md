# dbt-duckdb Adapter

> **Purpose**: Local dbt development with DuckDB as the warehouse -- zero infrastructure, instant builds
> **MCP Validated**: 2026-03-01

## When to Use

- Local dbt development and testing without a cloud warehouse
- CI/CD pipeline testing with no external dependencies
- Prototyping dbt models before deploying to Snowflake/BigQuery/Redshift
- Small-to-medium analytical projects that do not need a cloud warehouse
- dbt + Parquet/CSV file-based workflows (data lake querying)

## Implementation

```bash
# Install
pip install dbt-duckdb
# or with uv
uv add dbt-duckdb
```

**profiles.yml**:

```yaml
my_project:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: "target/dev.duckdb"  # Persistent file
      threads: 4
      extensions:
        - httpfs
        - parquet
      settings:
        s3_region: us-east-1

    # In-memory (faster, no persistence)
    test:
      type: duckdb
      path: ":memory:"
      threads: 4
```

**dbt_project.yml** (DuckDB-specific config):

```yaml
name: my_project
version: "1.0"

models:
  my_project:
    staging:
      +materialized: view
    marts:
      +materialized: table
```

**Source definition with external files**:

```yaml
# models/sources.yml
sources:
  - name: raw_files
    meta:
      external_location: "data/{name}.parquet"
    tables:
      - name: orders
      - name: customers
```

```sql
-- models/staging/stg_orders.sql
select
    order_id,
    customer_id,
    order_date,
    total_amount
from {{ source('raw_files', 'orders') }}
where order_date >= '2025-01-01'
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `path` | Required | Database file path or `:memory:` |
| `threads` | `1` | Parallel execution threads |
| `extensions` | `[]` | DuckDB extensions to load |
| `settings` | `{}` | DuckDB SET parameters |
| `external_root` | `.` | Root path for external sources |
| `attach` | `[]` | Additional databases to attach |
| `plugins` | `[]` | dbt-duckdb plugins (Excel, etc.) |

## DuckDB-Specific Materializations

```sql
-- models/external_export.sql
-- Export to Parquet (dbt-duckdb supports external materialization)
{{ config(materialized='external', location='output/report.parquet') }}

select
    department,
    sum(revenue) as total_revenue,
    count(distinct employee_id) as headcount
from {{ ref('fct_sales') }}
group by all
```

## Limitations vs Cloud Warehouses

| Feature | DuckDB | Snowflake/BigQuery |
|---------|--------|--------------------|
| Concurrency | Single writer | Multi-user |
| Scale | Single machine | Elastic compute |
| Data sharing | File copy | Live sharing |
| Scheduling | External (cron/Dagster) | Built-in |
| Source freshness | File timestamps | Metadata tables |
| Incremental | Supported | Supported |
| Snapshots | Supported | Supported |

## Example Usage

```bash
# Run dbt with DuckDB
dbt run --profiles-dir .

# Test
dbt test --profiles-dir .

# Build (run + test)
dbt build --profiles-dir .

# Generate docs
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .
```

## See Also

- [architecture](../concepts/architecture.md)
- [etl-processing](../patterns/etl-processing.md)
- [local-analytics](../patterns/local-analytics.md)
