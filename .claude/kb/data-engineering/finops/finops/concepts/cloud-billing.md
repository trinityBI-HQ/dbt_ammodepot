# Cloud Billing Models

> **Purpose**: Understanding AWS/GCP billing, pricing tiers, commitment discounts, and SaaS data platform pricing
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Cloud billing for data engineering spans infrastructure providers (AWS, GCP) and SaaS platforms (Snowflake, Databricks). Each has distinct pricing models with different levers for cost optimization. Understanding these models is essential for making informed commitment and architecture decisions.

## AWS Pricing for Data Workloads

### Compute (EC2/EMR)

| Pricing Type | Discount | Commitment | Best For |
|--------------|----------|------------|----------|
| On-Demand | 0% | None | Unpredictable, short-lived |
| Savings Plans (Compute) | Up to 72% | 1 or 3 year | Steady baseline compute |
| Reserved Instances | Up to 72% | 1 or 3 year | Specific instance types |
| Spot Instances | Up to 90% | None (can be interrupted) | Fault-tolerant Spark jobs |

**Strategy:** Savings Plans for baseline + Spot for burst capacity.

### Storage (S3)

| Storage Class | Cost/GB/Month | Access Pattern |
|---------------|---------------|----------------|
| S3 Standard | $0.023 | Frequent access |
| S3 Standard-IA | $0.0125 | Infrequent (1x/month) |
| S3 One Zone-IA | $0.010 | Infrequent, non-critical |
| S3 Glacier Instant | $0.004 | Rare, millisecond retrieval |
| S3 Glacier Flexible | $0.0036 | Archive, minutes-hours retrieval |
| S3 Glacier Deep Archive | $0.00099 | Long-term, 12-hour retrieval |
| S3 Intelligent-Tiering | $0.023 (auto) | Unknown/changing access |

**Data engineering pattern:** Bronze data in Standard (30 days) then transition to Standard-IA then Glacier. Use Intelligent-Tiering when access patterns are unpredictable.

### Analytics Services

| Service | Pricing Model | Optimization Lever |
|---------|---------------|-------------------|
| Athena | $5 per TB scanned | Columnar formats, partitioning |
| Glue ETL | DPU-hours | Right-size workers, G.2X |
| EMR | EC2 + EMR markup | Spot fleets, autoscaling |

## GCP Pricing for Data Workloads

### Compute (GCE/Dataproc)

| Pricing Type | Discount | Commitment |
|--------------|----------|------------|
| On-Demand | 0% | None |
| Sustained Use | Up to 30% | Automatic (>25% month usage) |
| Committed Use (CUD) | Up to 57% | 1 or 3 year |
| Preemptible/Spot VMs | Up to 91% | None (can be interrupted) |

### BigQuery Pricing

| Model | Cost | Best For |
|-------|------|----------|
| On-Demand | $6.25 per TB scanned | Low/variable query volume |
| Standard Edition | $0.04/slot-hour (autoscale) | Medium workloads |
| Enterprise Edition | $0.06/slot-hour (autoscale) | Cross-region, security |
| Enterprise Plus | $0.10/slot-hour | Mission-critical |

**Key optimization:** Partitioned and clustered tables reduce bytes scanned dramatically (up to 90%+ reduction).

### Storage (GCS)

| Class | Cost/GB/Month | Minimum Duration |
|-------|---------------|------------------|
| Standard | $0.020 | None |
| Nearline | $0.010 | 30 days |
| Coldline | $0.004 | 90 days |
| Archive | $0.0012 | 365 days |

## Snowflake Pricing

| Component | Pricing | Optimization |
|-----------|---------|-------------|
| **Compute** (credits) | $2-4/credit (edition-dependent) | Warehouse sizing, auto-suspend |
| **Storage** | ~$23/TB/month (on-demand) | Clustering, retention policies |
| **Data Transfer** | Varies by region/cloud | Minimize cross-region queries |

**Credit consumption by warehouse size:**

| Size | Credits/Hour | Use Case |
|------|-------------|----------|
| X-Small | 1 | Light queries, dev |
| Small | 2 | Standard ETL |
| Medium | 4 | Medium transforms |
| Large | 8 | Heavy processing |
| X-Large+ | 16+ | Large-scale, parallel |

## Databricks Pricing

| Workload Type | DBU Rate | Notes |
|---------------|----------|-------|
| Jobs Compute | 1x | Automated pipelines (cheapest) |
| All-Purpose | 2.5-4x | Interactive development (expensive) |
| SQL Warehouse (Serverless) | 1x | SQL analytics |
| DLT | 1.5x | Delta Live Tables pipelines |

**Critical insight:** Running pipeline code on All-Purpose clusters costs 3-4x more than Jobs clusters. Always use Jobs clusters for scheduled workloads.

## Quick Reference

| Provider | Cost Tool | Alert Mechanism |
|----------|-----------|-----------------|
| AWS | Cost Explorer, Budgets | SNS + Budget alerts |
| GCP | Billing Console, Budgets | Pub/Sub + Budget alerts |
| Snowflake | Account Usage views, Resource Monitors | Resource monitor alerts |
| Databricks | System tables, Cost Management | Budget policies |

## Related

- [Budgets and Forecasting](budgets-forecasting.md) -- Setting budgets based on billing models
- [Unit Economics](unit-economics.md) -- Translating billing into business metrics
- [Cost Allocation](cost-allocation.md) -- Allocating billing to teams
