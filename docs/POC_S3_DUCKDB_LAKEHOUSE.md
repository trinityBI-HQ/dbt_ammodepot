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
Airbyte CDC ──→ S3 Parquet (Bronze)  ──→  DuckDB+dbt (Fargate)  ──→  S3 Parquet (staging)  ──→  Snowflake COPY INTO (Gold)  ──→  Power BI
                ~$5-10/mo                  ~$5-15/mo                   ~$1-2/mo                   ~$20-50/mo (COPY + reads)
```

**Target total:** ~$31-77/mo

**Key design decisions:**
- **Bronze/Silver on S3** — Parquet format, DuckDB handles all transforms in memory
- **Gold written directly to Snowflake** — regular managed tables via `COPY INTO` / `MERGE INTO` from S3 staging
- **No Iceberg at Gold** — eliminates external tables, storage integrations, and catalog management
- **Power BI unchanged** — reads from the same `AD_ANALYTICS.GOLD` schema, same table names

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

### S3 Tables vs Traditional S3 — Decision

**Decision: Traditional S3 bucket.** S3 Tables (launched Dec 2024) was evaluated and rejected.

| Factor | Traditional S3 | S3 Tables |
|--------|---------------|-----------|
| Airbyte support | Native S3 destination | No native connector |
| DuckDB support | Native Parquet read/write | Experimental (preview since Mar 2025) |
| Snowflake Iceberg | Fully supported via external volume | Supported but adds catalog complexity |
| Compaction | You control it (DuckDB merge job) | Automatic but 2-3 hour delay, $0.05/GB |
| CDC workload fit | Excellent — append Parquet, dedup in DuckDB | Poor — small files trigger expensive compaction |
| Storage cost | $0.023/GB | $0.0265/GB (+15%) |
| Compaction cost | $0 (self-managed) | Est. $300-1000/mo for 64 streams @ 10min |
| Maturity | 18 years | ~15 months |

**Key disqualifiers:**
1. **Airbyte can't write to S3 Tables** — Bronze layer is dead on arrival
2. **Compaction cost explosion** — 64 streams every 10 min = hundreds of small files/day, each triggering $0.05/GB auto-compaction
3. **2-3 hour compaction delay** — conflicts with 10-min freshness SLA
4. **DuckDB support still experimental** — API may change

**Revisit when:** Airbyte adds native S3 Tables support AND compaction costs drop 5-10x. Check back in 12 months.

### Bucket Name

**`ammodepot-lakehouse`** — `us-east-1`, account `746669199691`

### Bucket Configuration

- **Versioning:** Disabled (Airbyte writes are append-only; Iceberg handles versioning at Gold layer)
- **Encryption:** SSE-S3 (default)
- **Public access:** Blocked (all four block public access settings enabled)

### Bucket Structure

```
s3://ammodepot-lakehouse/
├── bronze/                          # Raw Airbyte Parquet output (append-only)
│   ├── ad_fishbowl/{stream}/        # Partitioned by date
│   └── ad_magento/{stream}/         # Partitioned by date
└── staging/                         # DuckDB Gold output → Snowflake COPY INTO
    └── gold/
        ├── d_product/               # Full refresh Parquet files
        ├── d_customer/
        ├── f_sales_incremental/     # 3-day lookback window
        └── ...                      # Purged after each COPY INTO
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
      "Action": ["s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket", "s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::ammodepot-lakehouse/staging/*",
        "arn:aws:s3:::ammodepot-lakehouse"
      ]
    }
  ]
}
```

### Lifecycle Rules

| Prefix | Standard | Standard-IA | Glacier IR | Delete | Rationale |
|--------|----------|-------------|------------|--------|-----------|
| `bronze/` | 0-30d | 30-90d | 90-365d | 365d | Active DuckDB reads for 30d, then cold storage, delete after 1yr (Gold has the truth) |
| `silver/` | 0-30d | 30-180d | — | 180d | Intermediate layer, only kept for debugging/replay |
| `gold/` | Forever | — | — | Never | Active BI reads, small volume (~5GB), ~$0.12/mo |
| `iceberg/` | Forever | — | — | Never | Tiny metadata files, must stay accessible for Snowflake catalog |

**Additional policies:**
- Abort incomplete multipart uploads after 7 days (prevents orphaned fragments)
- Delete expired object delete markers (cleanup housekeeping)

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
  },
  {
    "ID": "AbortIncompleteUploads",
    "Filter": {"Prefix": ""},
    "Status": "Enabled",
    "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 7}
  }
]
```

---

## 5. Production Architecture — Airbyte S3 Data Lake (Iceberg) + AWS Glue Catalog

### Architecture Evolution

The POC validated the SQL logic using raw Parquet + full scans. For production with 10-minute freshness, the architecture uses **Airbyte S3 Data Lake destination** writing Iceberg format with **AWS Glue** as the catalog.

```
POC (validated):
  Airbyte → S3 Parquet (append) → DuckDB full scan + dedup → Silver → Gold

Production (target):
  Airbyte S3 Data Lake → S3 Iceberg (deduped by PK, Glue catalog)
                              ↓
                         DuckDB reads clean Iceberg (no dedup needed)
                              ↓
                         Silver transforms → Gold Parquet → Snowflake COPY INTO
```

### Why Airbyte S3 Data Lake + Iceberg

| Problem (Parquet) | Solution (Iceberg) |
|--------------------|-------------------|
| Full scan of all CDC files every 10 min | Iceberg metadata prunes files — read only what changed |
| `QUALIFY ROW_NUMBER()` dedup in every Silver model | Airbyte MERGE by PK — Bronze is always deduplicated |
| Small file accumulation (9,216 files/day) | Iceberg compaction manages file sizes automatically |
| 54-minute build for large tables (sales_order_item) | Incremental reads — seconds for 10-min CDC deltas |
| Manual Bronze compaction job | Iceberg snapshot management handles it |

### Airbyte S3 Data Lake Destination

| Setting | Value |
|---------|-------|
| Connector | S3 Data Lake (`716ca874-520b-4902-9f80-9fad66754b89`) |
| Format | Apache Iceberg (native) |
| Catalog | AWS Glue |
| CDC handling | MERGE by primary key (dedup + delete markers applied) |
| Sync mode | Incremental + Dedup (same as current Snowflake destination) |
| Version | 0.3.45+ (production-ready) |

### AWS Glue Catalog Configuration

```json
{
  "destination_type": "s3_data_lake",
  "s3_bucket_name": "ammodepot-lakehouse",
  "s3_bucket_region": "us-east-1",
  "catalog_config": {
    "catalog_type": "GLUE",
    "glue_database": "ammodepot_bronze",
    "glue_region": "us-east-1"
  }
}
```

**IAM for Glue:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GlueCatalog",
      "Effect": "Allow",
      "Action": [
        "glue:CreateDatabase",
        "glue:GetDatabase",
        "glue:CreateTable",
        "glue:GetTable",
        "glue:UpdateTable",
        "glue:DeleteTable",
        "glue:GetTables"
      ],
      "Resource": [
        "arn:aws:glue:us-east-1:746669199691:catalog",
        "arn:aws:glue:us-east-1:746669199691:database/ammodepot_bronze",
        "arn:aws:glue:us-east-1:746669199691:table/ammodepot_bronze/*"
      ]
    }
  ]
}
```

### S3 Bucket Structure (Production)

```
s3://ammodepot-lakehouse/
├── bronze/                          # Airbyte S3 Data Lake writes Iceberg here
│   ├── production2018/              # Fishbowl namespace
│   │   ├── so/                      # Iceberg table (data + metadata)
│   │   ├── soitem/
│   │   └── ...
│   └── ammuni_prod/                 # Magento namespace
│       ├── sales_order/
│       └── ...
├── staging/                         # DuckDB Gold output → Snowflake COPY INTO
│   └── gold/
│       ├── d_product/
│       ├── f_sales_incremental/
│       └── ...
└── (no landing/ prefix needed — Iceberg handles versioning via snapshots)
```

### DuckDB Reading from Iceberg (via Glue Catalog)

```yaml
# dbt-duckdb profiles.yml (production)
ammodepot_lakehouse:
  target: prod
  outputs:
    prod:
      type: duckdb
      path: ':memory:'
      extensions:
        - httpfs
        - iceberg
      settings:
        s3_region: us-east-1
```

```yaml
# Source definition reads from Glue-cataloged Iceberg tables
sources:
  - name: fishbowl
    meta:
      external_location: "s3://ammodepot-lakehouse/bronze/production2018/{name}"
      plugin: iceberg
    tables:
      - name: so
      - name: soitem
      # ... (no /*.parquet glob needed — Iceberg metadata handles file discovery)
```

### Silver Models Simplification

With Iceberg Bronze, Silver models **drop the CDC dedup boilerplate**:

```sql
-- BEFORE (Parquet, current POC):
with source_data as (
    select id, num, customerid, ...
    from {{ source('fishbowl', 'so') }}
    where _ab_cdc_deleted_at is null
    qualify row_number() over (
        partition by id
        order by try_cast(_ab_cdc_updated_at as timestamp) desc
    ) = 1
)
select * from source_data

-- AFTER (Iceberg, production):
with source_data as (
    select id, num, customerid, ...
    from {{ source('fishbowl', 'so') }}
    -- No dedup needed — Airbyte MERGE already deduplicated by PK
    -- No _ab_cdc_deleted_at filter — deletes already applied
)
select * from source_data
```

### Gold Layer — Unchanged

Gold is still written to regular Snowflake tables via `COPY INTO` / `MERGE INTO` (see Section 7). No Iceberg at Gold.

### S3 Staging Cleanup

```json
{
  "ID": "StagingCleanup",
  "Filter": {"Prefix": "staging/"},
  "Status": "Enabled",
  "Expiration": {"Days": 3}
}
```

### Maintenance

| Task | Who Handles It | Frequency |
|------|---------------|-----------|
| Bronze Iceberg compaction | Airbyte S3 Data Lake (automatic) | Per sync |
| Snapshot expiration | Airbyte S3 Data Lake (automatic) | Per sync |
| Orphan file cleanup | Periodic DuckDB/PyIceberg job | Weekly |
| S3 staging cleanup | Lifecycle rule + PURGE | Continuous |
| Gold table maintenance | Snowflake (automatic) | Continuous |

### Migration Path (POC → Production)

1. Create AWS Glue database `ammodepot_bronze`
2. Add Glue IAM permissions to `svc_airbyte-s3`
3. Create new Airbyte destination: `S3 Data Lake (Iceberg)` with Glue catalog
4. Create new connections: `Fishbowl → S3 Data Lake`, `Magento → S3 Data Lake`
5. Run initial sync (Iceberg snapshot = full table, same as current CDC snapshot)
6. Update dbt-duckdb sources to read Iceberg instead of Parquet glob
7. Remove dedup boilerplate from Silver models
8. Validate row counts match
9. Switch to 10-min scheduled syncs
10. Decommission old Parquet-based connections

---

## 6. DuckDB + dbt Transformation Layer

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

### Gold Output to S3 Staging (Parquet)

Gold models write Parquet to the `staging/gold/` prefix. Snowflake loads from there via `COPY INTO` (see Section 7).

```yaml
# dbt_project.yml (lakehouse version)
models:
  ammodepot:
    gold:
      +materialized: external
      +location: "s3://ammodepot-lakehouse/staging/gold/"
      +format: parquet
```

For incremental tables (f_sales), a custom macro exports only the lookback window:

```sql
-- macros/export_to_staging.sql
{% macro export_to_staging(table_name) %}
  COPY (SELECT * FROM {{ this }})
  TO 's3://ammodepot-lakehouse/staging/gold/{{ table_name }}/'
  (FORMAT PARQUET, COMPRESSION SNAPPY, OVERWRITE TRUE);
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
    "snowflake-connector-python>=3.6.0",
]
```

---

## 7. Snowflake Gold Layer — COPY INTO from S3

### Architecture Decision

**Gold is written directly to regular Snowflake managed tables** — no Iceberg, no external tables. DuckDB exports Gold results as Parquet to an S3 staging prefix, then Snowflake loads via `COPY INTO` (full refresh) or `MERGE INTO` (incremental).

**Why not Iceberg at Gold?**
- Power BI already reads from `AD_ANALYTICS.GOLD` — zero migration risk
- No storage integrations, external volumes, or catalog management needed
- Snowflake manages clustering, statistics, and maintenance automatically
- `COPY INTO` from Parquet is Snowflake's fastest bulk load path (vectorized scanner)

### Setup: S3 External Stage (One-Time)

```sql
USE ROLE SYSADMIN;

-- Storage integration for DuckDB staging area
CREATE OR REPLACE STORAGE INTEGRATION ammodepot_s3_int
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::746669199691:role/snowflake-lakehouse-role'
    ENABLED = TRUE
    STORAGE_ALLOWED_LOCATIONS = ('s3://ammodepot-lakehouse/staging/');

-- Get IAM external ID for trust policy
DESC STORAGE INTEGRATION ammodepot_s3_int;
-- Note STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID → add to IAM trust policy

USE ROLE TRANSFORMER_ROLE;

-- External stage pointing to Gold staging area
CREATE OR REPLACE STAGE AD_ANALYTICS.GOLD.S3_STAGING
    STORAGE_INTEGRATION = ammodepot_s3_int
    URL = 's3://ammodepot-lakehouse/staging/gold/'
    FILE_FORMAT = (TYPE = PARQUET);
```

### Pattern A: Full Refresh (12 Gold Tables)

DuckDB writes Parquet → Snowflake truncates and loads.

```sql
USE ROLE TRANSFORMER_ROLE;

-- Truncate and reload (atomic with transaction)
TRUNCATE TABLE AD_ANALYTICS.GOLD.D_PRODUCT;

COPY INTO AD_ANALYTICS.GOLD.D_PRODUCT
    FROM @AD_ANALYTICS.GOLD.S3_STAGING/d_product/
    FILE_FORMAT = (TYPE = PARQUET)
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
    PURGE = TRUE;
```

### Pattern B: Incremental Merge (f_sales — 3-Day Lookback)

DuckDB exports the 3-day window as Parquet → Snowflake merges.

```sql
USE ROLE TRANSFORMER_ROLE;

-- Merge incremental batch (same strategy as current dbt incremental)
MERGE INTO AD_ANALYTICS.GOLD.F_SALES t
USING (
    SELECT $1:ORDER_ID::NUMBER AS ORDER_ID,
           $1:ORDER_DATE::TIMESTAMP AS ORDER_DATE,
           $1:CUSTOMER_ID::NUMBER AS CUSTOMER_ID,
           -- ... all columns
    FROM @AD_ANALYTICS.GOLD.S3_STAGING/f_sales_incremental/
    (FILE_FORMAT => 'PARQUET')
) s
ON t.ORDER_ID = s.ORDER_ID
WHEN MATCHED THEN UPDATE SET
    t.ORDER_DATE = s.ORDER_DATE,
    t.CUSTOMER_ID = s.CUSTOMER_ID
    -- ... all columns
WHEN NOT MATCHED THEN INSERT (ORDER_ID, ORDER_DATE, CUSTOMER_ID, ...)
    VALUES (s.ORDER_ID, s.ORDER_DATE, s.CUSTOMER_ID, ...);
```

### S3 Staging Structure

```
s3://ammodepot-lakehouse/
├── bronze/                          # Airbyte CDC Parquet (append-only)
├── silver/                          # DuckDB intermediate output (optional)
├── staging/                         # DuckDB Gold output → Snowflake loads from here
│   └── gold/
│       ├── d_product/               # Full refresh Parquet
│       ├── d_customer/
│       ├── f_sales_incremental/     # 3-day lookback window
│       └── ...
└── (no iceberg/ prefix needed)
```

### Orchestration Flow

```
Fargate DuckDB task (every 10 min):
  1. Read Bronze Parquet from S3
  2. Transform: Bronze → Silver → Gold (all in-memory)
  3. Write Gold output as Parquet to s3://ammodepot-lakehouse/staging/gold/

Fargate Snowflake loader (after DuckDB completes):
  4. COPY INTO / MERGE INTO for each Gold table
  5. PURGE staged files after successful load

Power BI:
  6. Reads from AD_ANALYTICS.GOLD.* (unchanged)
```

---

## 8. POC Scope — Single Stream Validation

### POC Stream: `fishbowl.so` (Sales Orders)

**Why this stream:**
- Core table used by `f_sales` (most important Gold model)
- Incremental+Dedup sync — tests CDC handling
- Medium size — enough to validate performance, not so big it slows iteration
- Clear validation: row counts, totals, dates must match current Snowflake output

### POC Steps

#### Step 1: Create S3 Bucket (15 min)

```bash
aws s3 mb s3://ammodepot-lakehouse --region us-east-1 --profile ammodepot

# Create folder structure
aws s3api put-object --bucket ammodepot-lakehouse --key bronze/ --profile ammodepot
aws s3api put-object --bucket ammodepot-lakehouse --key staging/gold/ --profile ammodepot
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

#### Step 6: Write Gold Parquet to S3 Staging (30 min)

```python
# DuckDB transforms Bronze → Gold, writes Parquet to S3 staging
import duckdb

con = duckdb.connect()
con.execute("INSTALL httpfs; LOAD httpfs;")
con.execute("""
    SET s3_region = 'us-east-1';
    SET s3_access_key_id = 'YOUR_KEY';
    SET s3_secret_access_key = 'YOUR_SECRET';
""")

# Write Gold output as Parquet to staging (Snowflake will COPY INTO from here)
con.execute("""
    COPY (
        SELECT
            id              AS ORDER_ID,
            num             AS ORDER_NUMBER,
            customerid      AS CUSTOMER_ID,
            totalincludingtax AS TOTAL_INCLUDING_TAX
        FROM read_parquet('s3://ammodepot-lakehouse/bronze/ad_fishbowl/so/**/*.parquet')
        WHERE _ab_cdc_deleted_at IS NULL
        QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _ab_cdc_updated_at DESC) = 1
    )
    TO 's3://ammodepot-lakehouse/staging/gold/fishbowl_so_poc/'
    (FORMAT PARQUET, COMPRESSION SNAPPY, OVERWRITE TRUE)
""")
```

#### Step 7: Create Snowflake Stage + COPY INTO (30 min)

```sql
USE ROLE SYSADMIN;

-- Create storage integration (one-time)
CREATE OR REPLACE STORAGE INTEGRATION ammodepot_s3_int
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::746669199691:role/snowflake-lakehouse-role'
    ENABLED = TRUE
    STORAGE_ALLOWED_LOCATIONS = ('s3://ammodepot-lakehouse/staging/');

-- Get the AWS IAM external ID for trust policy
DESC STORAGE INTEGRATION ammodepot_s3_int;
-- Note: STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID
-- → Add these to the IAM role trust policy

USE ROLE TRANSFORMER_ROLE;

-- Create external stage
CREATE OR REPLACE STAGE AD_ANALYTICS.GOLD.S3_STAGING
    STORAGE_INTEGRATION = ammodepot_s3_int
    URL = 's3://ammodepot-lakehouse/staging/gold/'
    FILE_FORMAT = (TYPE = PARQUET);

-- Create POC table (regular Snowflake managed table)
CREATE OR REPLACE TABLE AD_ANALYTICS.GOLD.FISHBOWL_SO_POC (
    ORDER_ID NUMBER,
    ORDER_NUMBER VARCHAR,
    CUSTOMER_ID NUMBER,
    TOTAL_INCLUDING_TAX NUMBER(12,2)
);

-- Load from S3 staging
COPY INTO AD_ANALYTICS.GOLD.FISHBOWL_SO_POC
    FROM @AD_ANALYTICS.GOLD.S3_STAGING/fishbowl_so_poc/
    FILE_FORMAT = (TYPE = PARQUET)
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
    PURGE = TRUE;

-- Validate: compare row counts
SELECT count(*) FROM AD_ANALYTICS.GOLD.FISHBOWL_SO_POC;
-- Should match: SELECT count(*) FROM AD_ANALYTICS.SILVER.FISHBOWL_SO;
```

#### Step 8: Validate PBI Can Read It (15 min)

```sql
USE ROLE TRANSFORMER_ROLE;

GRANT SELECT ON TABLE AD_ANALYTICS.GOLD.FISHBOWL_SO_POC TO ROLE POWERBI_ROLE;
GRANT SELECT ON TABLE AD_ANALYTICS.GOLD.FISHBOWL_SO_POC TO ROLE POWERBI_READONLY_ROLE;
```

Then verify in Power BI that the table appears and returns data. This is a regular Snowflake table — PBI reads it exactly like existing Gold tables.

---

## 9. POC Success Criteria

| Criteria | How to Validate | Pass/Fail |
|---|---|---|
| Parquet files land correctly in S3 | `aws s3 ls s3://ammodepot-lakehouse/bronze/ad_fishbowl/so/` | |
| CDC columns preserved | DuckDB query shows `_ab_cdc_deleted_at`, `_ab_cdc_updated_at` | |
| Row count matches Snowflake | Compare `count(*)` between DuckDB Silver and Snowflake Silver | |
| Revenue total matches | Compare `sum(total_including_tax)` within $0.01 | |
| Deleted rows filtered correctly | DuckDB `WHERE _ab_cdc_deleted_at IS NULL` matches Snowflake count | |
| Dedup works correctly | `QUALIFY ROW_NUMBER()` produces same unique row count | |
| Snowflake COPY INTO succeeds | `COPY INTO` loads Parquet from S3 staging, row count matches | |
| PBI can query Gold table | Power BI refresh succeeds on `FISHBOWL_SO_POC` table | |
| DuckDB transform time < 5 min | Fargate task completes within SLA | |
| S3 storage cost < $1 for POC stream | Check S3 billing after 1 week | |

---

## 10. POC Timeline

| Day | Task | Effort |
|---|---|---|
| Day 1 | Create S3 bucket + lifecycle rules + IAM roles | 1 hour |
| Day 1 | Configure Airbyte S3 destination + POC connection (so stream) | 1 hour |
| Day 1 | Run first sync, validate Parquet output with DuckDB | 30 min |
| Day 2 | Build DuckDB Silver model, compare with Snowflake | 2 hours |
| Day 2 | Write Gold Parquet to S3 staging | 30 min |
| Day 2 | Create Snowflake storage integration + stage + COPY INTO | 1.5 hours |
| Day 3 | Validate PBI access, run success criteria checks | 1.5 hours |
| Day 3 | Document findings, go/no-go decision | 1 hour |

**Total POC effort:** ~3 days

---

## 11. Go/No-Go Decision Matrix

After POC, score each dimension:

| Dimension | Weight | Score (1-5) | Notes |
|---|---|---|---|
| Data accuracy (row counts, totals) | 30% | | Must be 5 to proceed |
| Transform performance (DuckDB speed) | 20% | | Must be ≥3 |
| PBI compatibility (COPY INTO tables) | 25% | | Must be ≥4 |
| Operational complexity | 15% | | Acceptable if ≥3 |
| Cost reduction validated | 10% | | Must show clear savings |

**Minimum to proceed:** Overall weighted score ≥ 3.5, no dimension below minimum

---

## 12. Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Airbyte S3 append-only creates too many small files | Medium | Medium | Add compaction job (DuckDB can merge Parquet files) |
| PBI performance degrades | Low | Medium | Gold is regular Snowflake tables — same performance as today |
| CDC ordering issues in append-only mode | Low | High | `QUALIFY ROW_NUMBER()` handles this — same as current Silver |
| S3 costs higher than expected | Low | Low | Lifecycle rules move old data to IA/Glacier |
| DuckDB memory limits on Fargate (1GB) | Low | Medium | Increase to 2GB if needed (~$7/mo extra) |
| Airbyte S3 destination doesn't preserve all CDC columns | Low | High | Validate in Step 4 before proceeding |

---

## 13. Cost Projection (Full Migration)

### Monthly Costs After Full Migration

| Component | Service | Cost |
|---|---|---|
| S3 storage (Bronze, ~50GB) | S3 Standard | ~$1.15/mo |
| S3 requests (PUT/GET) | S3 API | ~$5-10/mo |
| Fargate DuckDB task (10 min cycle) | ECS Fargate Spot | ~$5-15/mo |
| Snowflake (COPY INTO + PBI reads) | ETL_WH + COMPUTE_WH | ~$20-50/mo |
| Snowflake storage (Gold tables) | Snowflake | ~$5-10/mo |
| **Total** | | **~$36-86/mo** |

**Note:** Bronze lifecycle rules (IA at 30d, Glacier IR at 90d, delete at 365d) further reduce storage costs over time. S3 staging files are purged after each COPY INTO.

### Savings Summary

| | Current | After Migration | Savings |
|---|---|---|---|
| Monthly | ~$2,754 | ~$61 | ~$2,693/mo |
| Annual | ~$33,048 | ~$732 | **~$32,316/year** |

### Snowflake Contract Consideration

Check your Snowflake contract:
- If on **capacity pricing**, unused credits may be lost — negotiate a downgrade
- If on **on-demand**, savings are immediate
- If on **annual commit**, time the migration to align with renewal

---

## 14. Full Migration Phases (Post-POC)

### Phase 2: Fishbowl Migration (2 weeks)

- Move all 35 Fishbowl streams to S3 destination
- Port all Fishbowl Silver models to dbt-duckdb
- Validate all downstream Gold models

### Phase 3: Magento Migration (2 weeks)

- Move all 29 Magento streams to S3 destination
- Port all Magento Silver models (including EAV lookups)
- Special attention: `int_magento_product_eav_lookups` is complex

### Phase 4: Gold Layer COPY INTO (1 week)

- DuckDB computes all 13 Gold tables + intermediate views
- Write Gold output as Parquet to S3 staging
- Snowflake `COPY INTO` / `MERGE INTO` loads from staging
- Grant PBI roles access (same tables, same schema)

### Phase 5: Cutover (1 week)

- Run parallel: both architectures for 1 week
- Compare outputs daily (row counts, totals, specific records)
- Switch dbt orchestration from dbt-snowflake to DuckDB+COPY INTO pipeline
- Disable Airbyte → Snowflake connections
- Downgrade or cancel excess Snowflake capacity

---

## 15. ECS Deployment & Monitoring

### Cluster Strategy

**Same cluster (`ammodepot-dbt`), new task definition.** No reason for a separate cluster — Fargate tasks are isolated by definition.

| | Current (dbt-snowflake) | New (DuckDB Lakehouse) |
|--|------------------------|------------------------|
| Task family | `ammodepot-dbt-build` | `ammodepot-dbt-lakehouse` |
| ECR image | `ammodepot/dbt:latest` | `ammodepot/dbt-lakehouse:latest` |
| CPU / Memory | 0.5 vCPU / 1 GB | 1 vCPU / 2 GB |
| Dependencies | dbt-core + dbt-snowflake | dbt-core + dbt-duckdb + snowflake-connector |
| Entrypoint | dbt build → Snowflake | DuckDB build → S3 staging → Snowflake COPY INTO |
| Log group | `/ecs/ammodepot-dbt` | `/ecs/ammodepot-dbt-lakehouse` |
| Schedule | EventBridge rate(10 min) | EventBridge rate(10 min) |
| Capacity | Fargate Spot | Fargate Spot |

### Deployment Phases

```
POC (Day 1-3):
├── ammodepot-dbt-build        ← keeps production alive (every 10 min)
└── ammodepot-dbt-lakehouse    ← manual trigger only (POC validation)

Parallel Validation (1 week):
├── ammodepot-dbt-build        ← every 10 min (still primary)
└── ammodepot-dbt-lakehouse    ← every 10 min (compare outputs)

Cutover:
├── ammodepot-dbt-build        ← DISABLED (EventBridge rule disabled, not deleted)
└── ammodepot-dbt-lakehouse    ← every 10 min (now primary)
```

### Task Definition (Lakehouse)

```json
{
  "family": "ammodepot-dbt-lakehouse",
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "1024",
  "memory": "2048",
  "runtimePlatform": {
    "cpuArchitecture": "X86_64",
    "operatingSystemFamily": "LINUX"
  },
  "executionRoleArn": "arn:aws:iam::746669199691:role/ecsTaskExecutionRole-dbt",
  "taskRoleArn": "arn:aws:iam::746669199691:role/ecs-dbt-lakehouse-task-role",
  "containerDefinitions": [
    {
      "name": "dbt-lakehouse",
      "image": "746669199691.dkr.ecr.us-east-1.amazonaws.com/ammodepot/dbt-lakehouse:latest",
      "essential": true,
      "entryPoint": ["/app/entrypoint.sh"],
      "environment": [
        {"name": "SNOWFLAKE_ACCOUNT", "value": "iwb48385.us-east-1"},
        {"name": "SNOWFLAKE_DATABASE", "value": "AD_ANALYTICS"},
        {"name": "SNOWFLAKE_WAREHOUSE", "value": "ETL_WH"},
        {"name": "SNOWFLAKE_ROLE", "value": "TRANSFORMER_ROLE"},
        {"name": "SNOWFLAKE_USER", "value": "SVC_DBT"},
        {"name": "SNOWFLAKE_SCHEMA", "value": "gold"},
        {"name": "S3_BUCKET", "value": "ammodepot-lakehouse"},
        {"name": "S3_REGION", "value": "us-east-1"}
      ],
      "secrets": [
        {
          "name": "SNOWFLAKE_PRIVATE_KEY",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:746669199691:secret:ammodepot/dbt/snowflake-rwhWkq:SNOWFLAKE_PRIVATE_KEY::"
        },
        {
          "name": "SNOWFLAKE_PRIVATE_KEY_PASSPHRASE",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:746669199691:secret:ammodepot/dbt/snowflake-rwhWkq:SNOWFLAKE_PRIVATE_KEY_PASSPHRASE::"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/ammodepot-dbt-lakehouse",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "dbt-lakehouse"
        }
      }
    }
  ]
}
```

**Note:** S3 access uses the Fargate task role (IAM policy on `ecs-dbt-lakehouse-task-role`), not access keys. No AWS credentials needed in env vars or secrets.

### IAM — New Task Role

Create `ecs-dbt-lakehouse-task-role` with the existing dbt permissions plus S3 access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Lakehouse",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::ammodepot-lakehouse",
        "arn:aws:s3:::ammodepot-lakehouse/*"
      ]
    },
    {
      "Sid": "CloudWatchMetrics",
      "Effect": "Allow",
      "Action": "cloudwatch:PutMetricData",
      "Resource": "*"
    }
  ]
}
```

### CloudWatch Monitoring

**Same dashboard, new widgets. Same SNS topic, new alarms.**

| Resource | Current | Lakehouse |
|----------|---------|-----------|
| Log group | `/ecs/ammodepot-dbt` | `/ecs/ammodepot-dbt-lakehouse` |
| Dashboard | `ammodepot-dbt` | Same dashboard — add lakehouse widgets side-by-side |
| Build failure alarm | `dbt-build-failure` | `dbt-lakehouse-build-failure` (same `[31mERROR` filter) |
| Task missing alarm | `dbt-task-missing` | `dbt-lakehouse-task-missing` (no runs in 30 min) |
| Duration metric | `AmmoDepot/dbt/BuildDurationMinutes` | `AmmoDepot/dbt-lakehouse/BuildDurationMinutes` |
| SNS topic | Existing email topic | Same topic — one inbox for all alerts |

### Entrypoint (Lakehouse)

```bash
#!/bin/bash
set -euo pipefail

# Write Snowflake private key
if [ -n "${SNOWFLAKE_PRIVATE_KEY:-}" ]; then
    echo "$SNOWFLAKE_PRIVATE_KEY" > /tmp/dbt_rsa_key.p8
    chmod 600 /tmp/dbt_rsa_key.p8
    export SNOWFLAKE_PRIVATE_KEY_PATH=/tmp/dbt_rsa_key.p8
fi

cd /app/ammodepot

# Step 1: DuckDB transforms (Bronze → Silver → Gold Parquet on S3)
echo "=== DuckDB Transform ==="
START_TIME=$(date +%s)
uv run dbt build --profiles-dir . --target prod
DUCKDB_EXIT=$?

if [ $DUCKDB_EXIT -ne 0 ]; then
    echo "DuckDB transform failed with exit code $DUCKDB_EXIT"
    exit $DUCKDB_EXIT
fi

# Step 2: Snowflake COPY INTO from S3 staging
echo "=== Snowflake COPY INTO ==="
uv run python /app/scripts/snowflake_load.py
LOAD_EXIT=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$(echo "scale=2; $DURATION / 60" | bc)

echo "BUILD_DURATION_SECONDS=${DURATION}"
echo "BUILD_DURATION_MINUTES=${DURATION_MIN}"

# Publish duration metric
aws cloudwatch put-metric-data \
    --namespace AmmoDepot/dbt-lakehouse \
    --metric-name BuildDurationMinutes \
    --value "$DURATION_MIN" \
    --unit None \
    --region us-east-1 2>/dev/null || echo "Warning: Could not publish CloudWatch metric"

exit $LOAD_EXIT
```

### ECR Repository

```bash
aws ecr create-repository \
    --repository-name ammodepot/dbt-lakehouse \
    --image-scanning-configuration scanOnPush=true \
    --profile ammodepot
```

### Cost During Parallel Run

| Phase | Tasks Running | Monthly Cost |
|-------|--------------|-------------|
| POC | dbt-build (scheduled) + lakehouse (manual) | ~$3.70 + ~$0 = ~$3.70 |
| Parallel | dbt-build + lakehouse (both every 10 min) | ~$3.70 + ~$7.40 = ~$11.10 |
| Cutover | lakehouse only | ~$7.40 |
