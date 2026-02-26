# Snowflake Openflow

> **Purpose**: Managed data integration service built on Apache NiFi for any-to-any connectivity
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-25

## Overview

Snowflake Openflow is a managed integration service built on Apache NiFi, acquired via Datavolo in late 2024. It connects any data source to any destination using hundreds of processors supporting structured and unstructured data (text, images, audio, video, sensor data). BYOC deployment is GA in all AWS commercial regions (May 2025). SPCS (Snowflake-managed) deployment entered preview September 2025 and is now available on AWS and Azure.

## The Pattern

```text
Architecture: Two Deployment Models

BYOC (Bring Your Own Cloud):
+---------------------------+     +---------------------------+
| Snowflake Control Plane   |     | Your VPC (AWS)            |
| - Governance              | <-> | - Openflow Runtime        |
| - Monitoring              |     | - Data Processing Engine  |
| - Orchestration           |     | - NiFi Processors         |
+---------------------------+     +---------------------------+

SPCS (Snowflake Deployment):
+---------------------------------------------------+
| Snowflake Infrastructure                          |
| +---------------------+  +---------------------+ |
| | Control Plane       |  | SPCS Compute Pool   | |
| | - Governance        |  | - Openflow Runtime  | |
| | - Monitoring        |  | - NiFi Processors   | |
| +---------------------+  +---------------------+ |
+---------------------------------------------------+
```

```sql
-- SPCS Deployment: Create compute pool for Openflow
CREATE COMPUTE POOL openflow_pool
  MIN_NODES = 1
  MAX_NODES = 3
  INSTANCE_FAMILY = 'CPU_X64_M';

-- Authentication uses Snowflake Managed Tokens (recommended)
-- Short-lived, automatically refreshed, no long-lived credentials
```

## Quick Reference

| Deployment | Status | Regions | Data Plane | Control Plane |
|------------|--------|---------|------------|---------------|
| BYOC | GA (May 2025) | AWS commercial | Customer VPC | Snowflake |
| SPCS | GA (2025) | AWS + Azure commercial | Snowflake | Snowflake |

| Connector Category | Examples |
|--------------------|----------|
| Cloud Storage | Google Drive, Box, SharePoint, S3, GCS |
| SaaS Platforms | Salesforce, Workday, Jira, Slack |
| Advertising | Google Ads, Meta Ads, LinkedIn Ads, Amazon Ads |
| Databases | PostgreSQL, MySQL, SQL Server, Dataverse |
| Streaming | Kafka, Kinesis Data Streams |
| Productivity | Google Sheets |

| Feature | BYOC | SPCS |
|---------|------|------|
| Data residency | Your VPC | Snowflake infra |
| Auth method | Managed Token or Key-pair | Managed Token |
| PrivateLink | Yes (AWS) | N/A |
| Tri-Secret Secure | Yes | N/A |
| Secrets management | AWS Secrets Manager, Vault | Snowflake native |
| Billing | Per-vCPU-second (1 min min) | Credits (per-second) |

| Processor Type | Purpose |
|----------------|---------|
| Capture* | CDC replication (MySQL, PostgreSQL) |
| Fetch* | Pull data from APIs and services |
| Put* | Write data to destinations |
| Convert* | Transform data formats |
| Compress/Decompress | File compression handling |
| Cortex LLM | AI preprocessing in pipeline |

## Common Mistakes

### Wrong

```text
# Using long-lived credentials instead of Managed Tokens
# Risk: credential rotation burden, security exposure

# Over-provisioning compute pools for light workloads
# SPCS compute pools bill even when idle

# Not setting up error handling in NiFi flows
# Failed records silently lost without retry/DLQ
```

### Correct

```text
# Use Snowflake Managed Tokens (default, recommended)
# Automatic refresh, no credential management

# Right-size compute: start small, monitor, scale up
# BYOC: match vCPU count to throughput needs
# SPCS: use auto-scaling compute pools

# Configure retry and dead-letter handling
# Route failed records to error queues for investigation
# Set up monitoring via Snowflake control plane
```

## Related

- [snowpipe-streaming](../patterns/snowpipe-streaming.md)
- [stages](../concepts/stages.md)
- [openflow-integration](../patterns/openflow-integration.md)
