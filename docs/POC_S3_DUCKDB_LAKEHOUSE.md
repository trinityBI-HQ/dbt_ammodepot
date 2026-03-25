# POC: S3 + DuckDB + Iceberg Lakehouse

**Date:** 2026-03-23
**Status:** Planning
**Goal:** Validate S3+DuckDB+Iceberg architecture to replace Snowflake compute for ingestion and transformation
**Expected savings:** ~$2,400/mo ($31K/year) by eliminating 815 Snowflake credits/month

---

## 1. Current Architecture (Baseline)

```
Airbyte CDC ──→ Snowflake (AD_AIRBYTE)  ──→  dbt (Snowflake)  ──→  Gold tables  ──→  Power BI
                  678 credits/mo                137 credits/mo       103 credits/mo (reads)
                  ~$2,034/mo                    ~$411/mo             ~$309/mo
```

**Total:** ~$2,754/mo compute (~918 credits at $3/credit)

## 2. Target Architecture

```
Airbyte CDC ──→ S3 (Parquet)  ──→  DuckDB+dbt (Fargate)  ──→  S3 (Iceberg Gold)  ──→  Snowflake (Iceberg tables)  ──→  Power BI
                ~$5-10/mo           ~$5-15/mo                   ~$10-20/mo              ~$50-100/mo (reads only)
```

**Target total:** ~$70-145/mo

---

## 3. Airbyte S3 Destination — Format Decision

### Available Formats

| Format | DuckDB Support | Compression | Schema Evolution | CDC Columns | Recommendation |
|---|---|---|---|---|---|
| **Parquet** | Native, fastest | Snappy/GZIP | Limited | Preserved | **Best choice** |
| JSON | Native | GZIP | Flexible | Preserved | Fallback |
| CSV | Native | GZIP | None | Preserved | Not recommended |
| Avro | Via extension | Snappy | Good | Preserved | Overkill |

### Parquet — Why It Wins

- DuckDB reads Parquet from S3 at full speed with zero configuration
- Columnar format = only scan columns you need (massive for wide Magento tables)
- Snappy compression = 3-5x smaller than raw JSON
- Schema metadata embedded in file = self-documenting
- Airbyte preserves all CDC columns: `_ab_cdc_deleted_at`, `_ab_cdc_updated_at`, `_ab_cdc_log_pos`, `_airbyte_extracted_at`

### Airbyte S3 Destination Configuration

```json
{
  "destination_type": "s3",
  "s3_bucket_name": "ammodepot-lakehouse",
  "s3_bucket_region": "us-east-1",
  "s3_bucket_path": "bronze",
  "format": {
    "format_type": "Parquet",
    "compression_codec": "SNAPPY",
    "block_size_mb": 128,
    "max_padding_size_mb": 8,
    "page_size_kb": 1024
  },
  "s3_path_format": "${NAMESPACE}/${STREAM_NAME}/${YEAR}/${MONTH}/${DAY}/",
  "file_name_pattern": "{date}_{timestamp}_{part_number}"
}
```

### Resulting S3 Structure

```
s3://ammodepot-lakehouse/
└── bronze/
    ├── ad_fishbowl/
    │   ├── so/
    │   │   ├── 2026/03/23/20260323_1711200000_0.parquet
    │   │   ├── 2026/03/23/20260323_1711200600_0.parquet  (10 min later)
    │   │   └── ...
    │   ├── soitem/
    │   ├── product/
    │   ├── part/
    │   └── ... (35 streams)
    └── ad_magento/
        ├── sales_order/
        ├── sales_order_item/
        ├── customer_entity/
        └── ... (29 streams)
```

### CDC Behavior on S3

**Critical difference from Snowflake destination:**

| Behavior | Snowflake Destination | S3 Destination |
|---|---|---|
| Deduplication | Airbyte deduplicates (merge) | **Append-only** — all versions kept |
| Deletes | Airbyte removes deleted rows | **Delete markers kept** as rows with `_ab_cdc_deleted_at` set |
| Schema | Airbyte manages table schema | **Schema embedded** in each Parquet file |
| Incremental | Cursor-based, deduped at destination | Cursor-based, **dedup in DuckDB Silver layer** |

**This means:** The Silver layer in DuckDB must handle deduplication and delete filtering — exactly what your Silver models already do with `WHERE _ab_cdc_deleted_at IS NULL` and `QUALIFY ROW_NUMBER()`.

---

## 4. S3 Bucket Design

### Bucket Structure

```
s3://ammodepot-lakehouse/
├── bronze/                          # Raw Airbyte Parquet output
│   ├── ad_fishbowl/{stream}/        # Partitioned by date
│   └── ad_magento/{stream}/         # Partitioned by date
├── silver/                          # DuckDB-transformed views (Parquet)
│   ├── fishbowl/                    # Deduped, CDC-filtered, typed
│   └── magento/
├── gold/                            # Iceberg tables (read by Snowflake)
│   ├── f_sales/
│   ├── d_product/
│   ├── d_customer/
│   └── ...
└── iceberg/                         # Iceberg metadata catalog
    └── gold/
        └── metadata/
```

### Bucket Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AirbyteWrite",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::AIRBYTE_ROLE_ARN"},
      "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::ammodepot-lakehouse/bronze/*",
        "arn:aws:s3:::ammodepot-lakehouse"
      ]
    },
    {
      "Sid": "FargateTransform",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::FARGATE_TASK_ROLE_ARN"},
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::ammodepot-lakehouse/*",
        "arn:aws:s3:::ammodepot-lakehouse"
      ]
    },
    {
      "Sid": "SnowflakeRead",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::SNOWFLAKE_STORAGE_INT_ARN"},
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::ammodepot-lakehouse/gold/*",
        "arn:aws:s3:::ammodepot-lakehouse/iceberg/*",
        "arn:aws:s3:::ammodepot-lakehouse"
      ]
    }
  ]
}
```

### Lifecycle Rules

```json
[
  {
    "ID": "BronzeRetention",
    "Filter": {"Prefix": "bronze/"},
    "Status": "Enabled",
    "Transitions": [
      {"Days": 30, "StorageClass": "STANDARD_IA"},
      {"Days": 90, "StorageClass": "GLACIER_IR"}
    ],
    "Expiration": {"Days": 365}
  },
  {
    "ID": "SilverRetention",
    "Filter": {"Prefix": "silver/"},
    "Status": "Enabled",
    "Transitions": [
      {"Days": 30, "StorageClass": "STANDARD_IA"}
    ],
    "Expiration": {"Days": 180}
  }
]
```

---

## 5. DuckDB + dbt Transformation Layer

### dbt-duckdb Profile

```yaml
# profiles.yml
ammodepot_lakehouse:
  target: prod
  outputs:
    prod:
      type: duckdb
      path: ':memory:'
      extensions:
        - httpfs
        - iceberg
        - parquet
      settings:
        s3_region: us-east-1
        s3_access_key_id: "{{ env_var('AWS_ACCESS_KEY_ID') }}"
        s3_secret_access_key: "{{ env_var('AWS_SECRET_ACCESS_KEY') }}"
      external_root: "s3://ammodepot-lakehouse"
```

### Source Definition (reads from S3 Parquet)

```yaml
# models/bronze/fishbowl/_fishbowl_s3_sources.yml
sources:
  - name: fishbowl_s3
    schema: bronze_fishbowl
    meta:
      external_location: "s3://ammodepot-lakehouse/bronze/ad_fishbowl/{name}/**/*.parquet"
    tables:
      - name: so
      - name: soitem
      - name: product
      - name: part
      - name: vendor
      - name: ship
      - name: po
      - name: poitem
      - name: receipt
      - name: receiptitem
      - name: uomconversion
      - name: kititem
      - name: objecttoobject
```

### Silver Model Example (DuckDB SQL)

```sql
-- models/silver/fishbowl_so.sql
-- Same logic as current Snowflake model, adapted for DuckDB syntax
with source_data as (
    select
        id,
        num                             as order_number,
        customerid                      as customer_id,
        statusid                        as status_id,
        datecreated                     as date_created,
        datecompleted                   as date_completed,
        totalincludingtax               as total_including_tax,
        totaltax                        as total_tax,
        _ab_cdc_updated_at,
        _ab_cdc_deleted_at
    from {{ source('fishbowl_s3', 'so') }}
    where _ab_cdc_deleted_at is null
    qualify row_number() over (
        partition by id
        order by _ab_cdc_updated_at desc
    ) = 1
)

select * from source_data
```

### Gold Output to Iceberg

```yaml
# dbt_project.yml (lakehouse version)
models:
  ammodepot:
    gold:
      +materialized: external
      +location: "s3://ammodepot-lakehouse/gold/"
      +format: iceberg
```

Alternatively, for simpler Iceberg output with DuckDB:

```sql
-- macros/write_iceberg.sql
{% macro write_iceberg(table_name) %}
  COPY (SELECT * FROM {{ this }})
  TO 's3://ammodepot-lakehouse/gold/{{ table_name }}/'
  (FORMAT PARQUET, PARTITION_BY (none), OVERWRITE);
{% endmacro %}
```

### Fargate Task for DuckDB

```dockerfile
# ecs/Dockerfile.duckdb
FROM python:3.11-slim

RUN pip install uv
COPY pyproject.toml .
RUN uv sync

# dbt project
COPY ammodepot/ /app/ammodepot/
WORKDIR /app/ammodepot

ENTRYPOINT ["uv", "run", "dbt", "build", "--profiles-dir", ".", "--target", "prod"]
```

```toml
# pyproject.toml (lakehouse version)
[project]
name = "ammodepot-lakehouse"
requires-python = ">=3.11"
dependencies = [
    "dbt-core>=1.11.0",
    "dbt-duckdb>=1.11.0",
]
```

---

## 6. Snowflake Iceberg Integration (Gold Layer)

### Option A: Snowflake-Managed Iceberg Tables (Recommended for POC)

```sql
USE ROLE SYSADMIN;

-- Create storage integration for S3 access
CREATE OR REPLACE STORAGE INTEGRATION ammodepot_s3_int
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::ACCOUNT_ID:role/snowflake-lakehouse-role'
    ENABLED = TRUE
    STORAGE_ALLOWED_LOCATIONS = ('s3://ammodepot-lakehouse/gold/', 's3://ammodepot-lakehouse/iceberg/');

-- Create external volume
USE ROLE SYSADMIN;

CREATE OR REPLACE EXTERNAL VOLUME ammodepot_iceberg_vol
    STORAGE_LOCATIONS = (
        (
            NAME = 'ammodepot-gold'
            STORAGE_PROVIDER = 'S3'
            STORAGE_BASE_URL = 's3://ammodepot-lakehouse/gold/'
            STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::ACCOUNT_ID:role/snowflake-lakehouse-role'
        )
    );

-- Create Iceberg table (reads Gold layer from S3)
USE ROLE TRANSFORMER_ROLE;

CREATE OR REPLACE ICEBERG TABLE AD_ANALYTICS.GOLD.F_SALES_ICEBERG
    EXTERNAL_VOLUME = 'ammodepot_iceberg_vol'
    CATALOG = 'SNOWFLAKE'
    BASE_LOCATION = 'f_sales/';

-- Power BI reads from this table — same as before, just backed by S3
GRANT SELECT ON TABLE AD_ANALYTICS.GOLD.F_SALES_ICEBERG TO ROLE POWERBI_ROLE;
GRANT SELECT ON TABLE AD_ANALYTICS.GOLD.F_SALES_ICEBERG TO ROLE POWERBI_READONLY_ROLE;
```

### Option B: AWS Glue Catalog (More Complex, Better for Multi-Engine)

```sql
USE ROLE SYSADMIN;

-- Create catalog integration with Glue
CREATE OR REPLACE CATALOG INTEGRATION ammodepot_glue_catalog
    CATALOG_SOURCE = GLUE
    CATALOG_NAMESPACE = 'ammodepot_gold'
    TABLE_FORMAT = ICEBERG
    GLUE_AWS_ROLE_ARN = 'arn:aws:iam::ACCOUNT_ID:role/snowflake-glue-role'
    GLUE_CATALOG_ID = 'ACCOUNT_ID'
    GLUE_REGION = 'us-east-1'
    ENABLED = TRUE;
```

**Recommendation:** Start with Option A (Snowflake-managed) for simplicity. Migrate to Glue catalog later if needed.

---

## 7. POC Scope — Single Stream Validation

### POC Stream: `fishbowl.so` (Sales Orders)

**Why this stream:**
- Core table used by `f_sales` (most important Gold model)
- Incremental+Dedup sync — tests CDC handling
- Medium size — enough to validate performance, not so big it slows iteration
- Clear validation: row counts, totals, dates must match current Snowflake output

### POC Steps

#### Step 1: Create S3 Bucket (15 min)

```bash
aws s3 mb s3://ammodepot-lakehouse --region us-east-1

# Create folder structure
aws s3api put-object --bucket ammodepot-lakehouse --key bronze/
aws s3api put-object --bucket ammodepot-lakehouse --key silver/
aws s3api put-object --bucket ammodepot-lakehouse --key gold/
aws s3api put-object --bucket ammodepot-lakehouse --key iceberg/
```

#### Step 2: Configure Airbyte S3 Destination (30 min)

1. In Airbyte UI, go to **Destinations** > **New Destination**
2. Select **S3**
3. Configure:
   - Bucket: `ammodepot-lakehouse`
   - Path: `bronze`
   - Region: `us-east-1`
   - Format: **Parquet** (Snappy compression)
   - Path format: `${NAMESPACE}/${STREAM_NAME}/${YEAR}/${MONTH}/${DAY}/`
4. Test connection

#### Step 3: Create POC Airbyte Connection (15 min)

1. Create new connection: **Fishbowl → S3 (POC)**
2. Select only the `so` stream
3. Sync mode: **Incremental + Append** (S3 doesn't support Dedup)
4. Frequency: **Manual** (trigger manually during POC)
5. Run first sync
6. Verify Parquet files appear in `s3://ammodepot-lakehouse/bronze/ad_fishbowl/so/`

#### Step 4: Validate Parquet Output (15 min)

```python
# Quick validation script (run locally or on EC2)
import duckdb

con = duckdb.connect()
con.execute("INSTALL httpfs; LOAD httpfs;")
con.execute("""
    SET s3_region = 'us-east-1';
    SET s3_access_key_id = 'YOUR_KEY';
    SET s3_secret_access_key = 'YOUR_SECRET';
""")

# Count rows
result = con.execute("""
    SELECT count(*) as total_rows,
           count(distinct id) as unique_ids,
           min(_ab_cdc_updated_at) as earliest,
           max(_ab_cdc_updated_at) as latest,
           count_if(_ab_cdc_deleted_at is not null) as deleted_rows
    FROM read_parquet('s3://ammodepot-lakehouse/bronze/ad_fishbowl/so/**/*.parquet')
""").fetchall()
print(result)
```

#### Step 5: Build DuckDB Silver Model (1 hour)

```sql
-- Compare DuckDB output vs current Snowflake Silver
-- Run in DuckDB:
WITH s3_data AS (
    SELECT *
    FROM read_parquet('s3://ammodepot-lakehouse/bronze/ad_fishbowl/so/**/*.parquet')
    WHERE _ab_cdc_deleted_at IS NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY _ab_cdc_updated_at DESC
    ) = 1
)
SELECT count(*) as row_count,
       sum(totalincludingtax) as total_revenue
FROM s3_data;

-- Compare with Snowflake:
-- USE ROLE TRANSFORMER_ROLE;
-- SELECT count(*), sum(total_including_tax) FROM AD_ANALYTICS.SILVER.FISHBOWL_SO;
```

#### Step 6: Write Gold Iceberg Table (1 hour)

```python
# Write Iceberg from DuckDB to S3
import duckdb

con = duckdb.connect()
con.execute("INSTALL httpfs; LOAD httpfs; INSTALL iceberg; LOAD iceberg;")
# ... S3 config ...

# Write Gold output as Parquet (Iceberg metadata managed by Snowflake)
con.execute("""
    COPY (
        SELECT
            id,
            num AS ORDER_NUMBER,
            customerid AS CUSTOMER_ID,
            totalincludingtax AS TOTAL_INCLUDING_TAX
        FROM read_parquet('s3://ammodepot-lakehouse/bronze/ad_fishbowl/so/**/*.parquet')
        WHERE _ab_cdc_deleted_at IS NULL
        QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _ab_cdc_updated_at DESC) = 1
    )
    TO 's3://ammodepot-lakehouse/gold/fishbowl_so_poc/'
    (FORMAT PARQUET, OVERWRITE TRUE)
""")
```

#### Step 7: Create Snowflake External Table (30 min)

```sql
USE ROLE SYSADMIN;

-- Create storage integration (one-time)
CREATE OR REPLACE STORAGE INTEGRATION ammodepot_s3_int
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::746669199691:role/snowflake-lakehouse-role'
    ENABLED = TRUE
    STORAGE_ALLOWED_LOCATIONS = ('s3://ammodepot-lakehouse/');

-- Get the AWS IAM external ID for trust policy
DESC STORAGE INTEGRATION ammodepot_s3_int;
-- Note: STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID
-- → Add these to the IAM role trust policy

USE ROLE SYSADMIN;

-- Create stage pointing to Gold
CREATE OR REPLACE STAGE AD_ANALYTICS.GOLD.S3_GOLD_STAGE
    STORAGE_INTEGRATION = ammodepot_s3_int
    URL = 's3://ammodepot-lakehouse/gold/'
    FILE_FORMAT = (TYPE = PARQUET);

USE ROLE TRANSFORMER_ROLE;

-- Create external table for POC validation
CREATE OR REPLACE EXTERNAL TABLE AD_ANALYTICS.GOLD.FISHBOWL_SO_POC (
    ID NUMBER AS (value:id::number),
    ORDER_NUMBER VARCHAR AS (value:ORDER_NUMBER::varchar),
    CUSTOMER_ID NUMBER AS (value:CUSTOMER_ID::number),
    TOTAL_INCLUDING_TAX NUMBER(12,2) AS (value:TOTAL_INCLUDING_TAX::number(12,2))
)
LOCATION = @AD_ANALYTICS.GOLD.S3_GOLD_STAGE/fishbowl_so_poc/
FILE_FORMAT = (TYPE = PARQUET)
AUTO_REFRESH = TRUE;

-- Validate: compare row counts
SELECT count(*) FROM AD_ANALYTICS.GOLD.FISHBOWL_SO_POC;
-- Should match: SELECT count(*) FROM AD_ANALYTICS.SILVER.FISHBOWL_SO;
```

#### Step 8: Validate PBI Can Read It (15 min)

```sql
USE ROLE SYSADMIN;

GRANT SELECT ON TABLE AD_ANALYTICS.GOLD.FISHBOWL_SO_POC TO ROLE POWERBI_ROLE;
GRANT SELECT ON TABLE AD_ANALYTICS.GOLD.FISHBOWL_SO_POC TO ROLE POWERBI_READONLY_ROLE;
```

Then verify in Power BI that the external table appears and returns data.

---

## 8. POC Success Criteria

| Criteria | How to Validate | Pass/Fail |
|---|---|---|
| Parquet files land correctly in S3 | `aws s3 ls s3://ammodepot-lakehouse/bronze/ad_fishbowl/so/` | |
| CDC columns preserved | DuckDB query shows `_ab_cdc_deleted_at`, `_ab_cdc_updated_at` | |
| Row count matches Snowflake | Compare `count(*)` between DuckDB Silver and Snowflake Silver | |
| Revenue total matches | Compare `sum(total_including_tax)` within $0.01 | |
| Deleted rows filtered correctly | DuckDB `WHERE _ab_cdc_deleted_at IS NULL` matches Snowflake count | |
| Dedup works correctly | `QUALIFY ROW_NUMBER()` produces same unique row count | |
| Snowflake reads Iceberg/external table | `SELECT count(*)` from external table returns correct count | |
| PBI can query the external table | Power BI refresh succeeds on external table | |
| DuckDB transform time < 5 min | Fargate task completes within SLA | |
| S3 storage cost < $1 for POC stream | Check S3 billing after 1 week | |

---

## 9. POC Timeline

| Day | Task | Effort |
|---|---|---|
| Day 1 | Create S3 bucket + IAM roles + Airbyte S3 destination | 2 hours |
| Day 1 | Create POC Airbyte connection (so stream only) | 30 min |
| Day 1 | Run first sync, validate Parquet output | 30 min |
| Day 2 | Build DuckDB Silver model, compare with Snowflake | 2 hours |
| Day 2 | Write Gold output to S3, create Snowflake external table | 2 hours |
| Day 3 | Validate PBI access, run success criteria checks | 2 hours |
| Day 3 | Document findings, go/no-go decision | 1 hour |

**Total POC effort:** ~3 days

---

## 10. Go/No-Go Decision Matrix

After POC, score each dimension:

| Dimension | Weight | Score (1-5) | Notes |
|---|---|---|---|
| Data accuracy (row counts, totals) | 30% | | Must be 5 to proceed |
| Transform performance (DuckDB speed) | 20% | | Must be ≥3 |
| PBI compatibility (external tables) | 25% | | Must be ≥4 |
| Operational complexity | 15% | | Acceptable if ≥3 |
| Cost reduction validated | 10% | | Must show clear savings |

**Minimum to proceed:** Overall weighted score ≥ 3.5, no dimension below minimum

---

## 11. Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Airbyte S3 append-only creates too many small files | Medium | Medium | Add compaction job (DuckDB can merge Parquet files) |
| PBI performance on external tables is slow | Medium | High | Use materialized views in Snowflake on top of external tables |
| CDC ordering issues in append-only mode | Low | High | `QUALIFY ROW_NUMBER()` handles this — same as current Silver |
| S3 costs higher than expected | Low | Low | Lifecycle rules move old data to IA/Glacier |
| DuckDB memory limits on Fargate (1GB) | Low | Medium | Increase to 2GB if needed (~$7/mo extra) |
| Airbyte S3 destination doesn't preserve all CDC columns | Low | High | Validate in Step 4 before proceeding |

---

## 12. Cost Projection (Full Migration)

### Monthly Costs After Full Migration

| Component | Service | Cost |
|---|---|---|
| S3 storage (Bronze, ~50GB) | S3 Standard | ~$1.15/mo |
| S3 storage (Silver, ~20GB) | S3 Standard | ~$0.46/mo |
| S3 storage (Gold Iceberg, ~5GB) | S3 Standard | ~$0.12/mo |
| S3 requests (PUT/GET) | S3 API | ~$5-10/mo |
| Fargate DuckDB task (10 min cycle) | ECS Fargate Spot | ~$5-15/mo |
| Snowflake (PBI reads only) | COMPUTE_WH | ~$50-100/mo |
| Snowflake storage (metadata only) | Snowflake | ~$5/mo |
| **Total** | | **~$67-132/mo** |

### Savings Summary

| | Current | After Migration | Savings |
|---|---|---|---|
| Monthly | ~$2,754 | ~$100 | ~$2,654/mo |
| Annual | ~$33,048 | ~$1,200 | **~$31,848/year** |

### Snowflake Contract Consideration

Check your Snowflake contract:
- If on **capacity pricing**, unused credits may be lost — negotiate a downgrade
- If on **on-demand**, savings are immediate
- If on **annual commit**, time the migration to align with renewal

---

## 13. Full Migration Phases (Post-POC)

### Phase 2: Fishbowl Migration (2 weeks)

- Move all 35 Fishbowl streams to S3 destination
- Port all Fishbowl Silver models to dbt-duckdb
- Validate all downstream Gold models

### Phase 3: Magento Migration (2 weeks)

- Move all 29 Magento streams to S3 destination
- Port all Magento Silver models (including EAV lookups)
- Special attention: `int_magento_product_eav_lookups` is complex

### Phase 4: Gold Layer Iceberg (1 week)

- Convert all 13 Gold tables + 8 intermediate views to Iceberg output
- Create Snowflake external tables for each
- Grant PBI roles access

### Phase 5: Cutover (1 week)

- Run parallel: both architectures for 1 week
- Compare outputs daily
- Switch PBI to read from Iceberg-backed tables
- Disable Airbyte → Snowflake connections
- Downgrade or cancel excess Snowflake capacity
