# Openflow Integration Pattern

> **Purpose**: Configuring Snowflake Openflow for data ingestion from diverse sources
> **MCP Validated**: 2026-02-25

## When to Use

- Ingesting unstructured data (images, PDFs, audio, video) for AI/ML pipelines
- Real-time CDC replication from operational databases (MySQL, PostgreSQL)
- Consolidating SaaS data (Salesforce, Workday, Google Ads) into Snowflake
- Streaming event data from Kafka/Kinesis for analytics
- Replacing custom ETL scripts with managed, visual pipeline builder
- Preprocessing data with Cortex LLM functions before loading

## Implementation

```text
# === BYOC Deployment (AWS) ===

# Step 1: Create an Openflow account link in Snowflake
# Navigate to: Snowsight > Data > Openflow > Setup

# Step 2: Deploy runtime in your AWS VPC
# Openflow provisions infrastructure in your account
# Control plane remains in Snowflake for governance

# Step 3: Configure authentication (Snowflake Managed Token)
# Recommended: automatic token refresh, no credentials to manage
# Alternative: Key-pair authentication for BYOC

# === SPCS Deployment ===

# Step 1: Create compute pool
CREATE COMPUTE POOL openflow_pool
  MIN_NODES = 1
  MAX_NODES = 3
  INSTANCE_FAMILY = 'CPU_X64_M'
  AUTO_RESUME = TRUE
  AUTO_SUSPEND_SECS = 300;

# Step 2: Grant required privileges
GRANT USAGE ON COMPUTE POOL openflow_pool TO ROLE openflow_admin;
GRANT CREATE SERVICE ON SCHEMA openflow_schema TO ROLE openflow_admin;

# Step 3: Deploy Openflow runtime via Snowsight
# Navigate to: Data > Openflow > Create Deployment > Snowflake

# === Common Pipeline Patterns ===

# Pattern 1: Database CDC to Snowflake
# Source: MySQL (CaptureChangeMySQL processor)
# -> Transform: Convert to JSON
# -> Destination: PutSnowflake processor
# -> Target: RAW.CDC_EVENTS table

# Pattern 2: SaaS API to Snowflake
# Source: FetchSalesforce / FetchWorkday processor
# -> Transform: ConvertRecord (CSV/JSON)
# -> Destination: PutSnowflake
# -> Target: RAW.SALESFORCE_ACCOUNTS table

# Pattern 3: Unstructured Data + AI Preprocessing
# Source: FetchGoogleDrive / FetchSharePoint
# -> Process: Cortex LLM processor (classify, extract, embed)
# -> Transform: ConvertRecord
# -> Destination: PutSnowflake
# -> Target: RAW.DOCUMENTS table with VARIANT column

# Pattern 4: Kafka Streaming to Snowflake
# Source: ConsumeKafka processor
# -> Transform: ConvertJSON
# -> Destination: PutSnowflake
# -> Target: RAW.STREAM_EVENTS table
```

## Configuration

| Setting | BYOC | SPCS | Notes |
|---------|------|------|-------|
| Auth method | Managed Token (default) | Managed Token | Key-pair also for BYOC |
| Encryption | TLS in transit | TLS in transit | At-rest per cloud provider |
| PrivateLink | Supported (AWS) | N/A | Secure cross-account access |
| Scaling | Manual vCPU | Auto-scale nodes | SPCS uses compute pools |
| Secrets | AWS Secrets Manager, Vault | Snowflake native | For source credentials |
| Monitoring | Snowflake control plane | Snowflake control plane | Unified observability |

| Cost Component | BYOC | SPCS |
|----------------|------|------|
| Compute | Per-vCPU-second (1 min min) | Credits per-second |
| Storage | Cloud provider rates | Snowflake storage rates |
| Data transfer | Cloud provider rates | Snowflake transfer rates |
| Control plane | Included | Included |

## Example Usage

```text
# Migrating from custom Python ETL to Openflow

# Before (custom script):
# - Python script with requests library
# - Cron job every 15 minutes
# - Manual error handling and retries
# - No monitoring or governance

# After (Openflow):
# 1. Create deployment (BYOC or SPCS)
# 2. Add source processor (e.g., FetchSalesforce)
# 3. Configure credentials via Managed Token
# 4. Add transformation processors (ConvertRecord, etc.)
# 5. Add PutSnowflake destination processor
# 6. Configure scheduling (cron or continuous)
# 7. Enable monitoring in Snowflake control plane

# Key processors for common sources:
# - CaptureChangeMySQL / CaptureChangePostgreSQL (CDC)
# - FetchSalesforce / FetchWorkday / FetchJiraCloud (SaaS)
# - ConsumeKafka / ConsumeKinesisStream (Streaming)
# - FetchGoogleDrive / FetchSharePoint / FetchBox (Files)
# - GetS3Object / GetGCSObject (Cloud Storage)

# AI preprocessing in pipeline:
# - Use Cortex LLM processor to classify/extract/embed
# - Process unstructured text before loading
# - Build "chat with your data" pipelines
```

## See Also

- [openflow](../concepts/openflow.md)
- [snowpipe-streaming](../patterns/snowpipe-streaming.md)
- [copy-into-loading](../patterns/copy-into-loading.md)
