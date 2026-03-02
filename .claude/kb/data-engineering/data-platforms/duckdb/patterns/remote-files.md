# Querying Remote Files

> **Purpose**: Querying files on S3, GCS, and Azure Blob Storage using httpfs, with Iceberg and Delta Lake table scanning
> **MCP Validated**: 2026-03-01

## When to Use

- Querying Parquet/CSV files stored in S3, GCS, or Azure Blob without downloading
- Exploring data lake files interactively from a local DuckDB instance
- Scanning Apache Iceberg or Delta Lake tables from cloud storage
- Ad-hoc analysis on cloud-stored datasets (no warehouse needed)
- Combining local and remote data sources in a single query

## Implementation

```sql
-- Install and configure S3 access
install httpfs;
load httpfs;

-- Option 1: Secrets Manager (recommended)
create secret my_s3_secret (
    type s3,
    key_id 'AKIAIOSFODNN7EXAMPLE',
    secret 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
    region 'us-east-1'
);

-- Option 2: SET parameters
set s3_region = 'us-east-1';
set s3_access_key_id = 'AKIAIOSFODNN7EXAMPLE';
set s3_secret_access_key = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';

-- Option 3: AWS credential chain (uses ~/.aws/credentials or env vars)
create secret (type s3, provider credential_chain);

-- Query remote Parquet
select count(*) from read_parquet('s3://my-bucket/data/sales.parquet');

-- Glob patterns on S3
select * from read_parquet('s3://my-bucket/data/year=2025/**/*.parquet');

-- Include filename in results
select *, filename
from read_parquet('s3://my-bucket/data/*.parquet', filename = true);

-- Hive partitioning on remote files
select * from read_parquet('s3://my-bucket/partitioned/',
    hive_partitioning = true
) where year = 2025 and month = 3;
```

## GCS and Azure

```sql
-- Google Cloud Storage (uses S3-compatible endpoint)
create secret gcs_secret (
    type gcs,
    key_id 'GOOG...',
    secret 'secret...'
);
select * from read_parquet('gcs://my-bucket/data.parquet');

-- Shorthand gs:// also works
select * from read_parquet('gs://my-bucket/data.parquet');

-- Azure Blob Storage
install azure;
load azure;
create secret azure_secret (
    type azure,
    connection_string 'DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...'
);
select * from read_parquet('az://container/path/data.parquet');

-- Azure with SAS token
create secret (
    type azure,
    account_name 'myaccount',
    sas_token 'sv=2021-06-08&ss=b...'
);
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `s3_region` | None | AWS region |
| `s3_endpoint` | AWS default | Custom S3-compatible endpoint (MinIO, etc.) |
| `s3_use_ssl` | `true` | Use HTTPS for S3 |
| `s3_url_style` | `vhost` | S3 URL style: `vhost` or `path` |
| `http_keep_alive` | `true` | Reuse HTTP connections |
| `http_retries` | `3` | Number of HTTP retry attempts |

## Iceberg and Delta Lake

```sql
-- Apache Iceberg tables
install iceberg;
load iceberg;
select * from iceberg_scan('s3://warehouse/db/orders');

-- Iceberg metadata
select * from iceberg_metadata('s3://warehouse/db/orders');
select * from iceberg_snapshots('s3://warehouse/db/orders');

-- Delta Lake tables
install delta;
load delta;
select * from delta_scan('s3://lake/delta-table/');
```

## Example Usage

```python
import duckdb

con = duckdb.connect()

# Configure credentials from environment
import os
con.sql(f"""
    create secret s3 (
        type s3,
        key_id '{os.environ["AWS_ACCESS_KEY_ID"]}',
        secret '{os.environ["AWS_SECRET_ACCESS_KEY"]}',
        region '{os.environ.get("AWS_REGION", "us-east-1")}'
    )
""")

# Query remote data, join with local data
local_mapping = con.sql("select * from 'product_categories.csv'")

result = con.sql("""
    select
        p.product_id,
        c.category_name,
        sum(s.quantity) as total_sold
    from read_parquet('s3://datalake/sales/*.parquet') s
    join read_parquet('s3://datalake/products.parquet') p
        on s.product_id = p.product_id
    join local_mapping c
        on p.category_id = c.category_id
    group by all
    order by total_sold desc
    limit 20
""").df()

print(result)
```

## See Also

- [extensions](../concepts/extensions.md)
- [data-import-export](../concepts/data-import-export.md)
- [performance-tuning](../patterns/performance-tuning.md)
