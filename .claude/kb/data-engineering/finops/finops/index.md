# FinOps Knowledge Base

> **Purpose**: Financial operations framework for technology cost optimization (cloud, SaaS, GenAI, data centers)
> **MCP Validated**: 2026-02-19

## Quick Navigation

| File | Purpose |
|------|---------|
| [concepts/framework.md](concepts/framework.md) | FinOps Framework phases: Inform, Optimize, Operate |
| [concepts/cost-allocation.md](concepts/cost-allocation.md) | Tagging, showback, chargeback, cost centers |
| [concepts/cloud-billing.md](concepts/cloud-billing.md) | AWS/GCP billing models, reservations, savings plans |
| [concepts/unit-economics.md](concepts/unit-economics.md) | Cost per query, per pipeline run, per GB processed |
| [concepts/budgets-forecasting.md](concepts/budgets-forecasting.md) | Budget alerts, forecasting models, anomaly detection |
| [concepts/governance.md](concepts/governance.md) | Policies, approval workflows, guardrails, waste detection |
| [patterns/data-pipeline-optimization.md](patterns/data-pipeline-optimization.md) | Spark/Databricks cluster optimization, spot instances |
| [patterns/warehouse-cost-management.md](patterns/warehouse-cost-management.md) | Snowflake credits, BigQuery slots, warehouse sizing |
| [patterns/storage-optimization.md](patterns/storage-optimization.md) | S3 lifecycle policies, storage classes, data tiering |
| [patterns/monitoring-alerting.md](patterns/monitoring-alerting.md) | Cost dashboards, alerts, anomaly detection, automation |
| [quick-reference.md](quick-reference.md) | Fast lookup tables for cost optimization |

## The FinOps Lifecycle

```
    +----------+     +----------+     +---------+
    |  INFORM  | --> | OPTIMIZE | --> | OPERATE |
    +----------+     +----------+     +---------+
         ^                                 |
         +---------------------------------+
```

- **Inform**: Visibility into who spends what, where, and why
- **Optimize**: Right-size, commit, architect for efficiency
- **Operate**: Govern, automate, and enforce policies

## FinOps Framework 2025: Scopes

| Scope | Examples | Data Engineering Relevance |
|-------|----------|---------------------------|
| **Public Cloud** | AWS, GCP, Azure | Core infrastructure for data pipelines |
| **SaaS** | Snowflake, Databricks, Fivetran | Major data platform cost centers |
| **GenAI** | OpenAI, Bedrock, Vertex AI | LLM/AI pipeline costs (tokens, inference) |
| **Data Center** | On-prem Hadoop, Spark clusters | Hybrid deployments |
| **Licensing** | Oracle, SAP, Tableau | Software license cost management |

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Cost Allocation** | Mapping spend to teams, projects, and pipelines via tags |
| **Unit Economics** | Cost per business unit (query, pipeline run, GB, LLM token) |
| **Commitment Discounts** | Reserved Instances, Savings Plans, CUDs for predictable workloads |
| **Right-Sizing** | Matching compute resources to actual workload requirements |
| **Storage Tiering** | Moving data to cheaper storage classes based on access patterns |
| **Waste Detection** | Finding idle resources, unused storage, over-provisioned compute |

## Data Engineering Cost Drivers

| Workload | Key Cost Drivers | Optimization Levers |
|----------|------------------|---------------------|
| Spark/Databricks | Cluster size, DBUs, spot usage | Right-size, autoscale, Jobs clusters |
| Snowflake | Credits, warehouse size | Warehouse sizing, query optimization |
| BigQuery | Bytes scanned, slot reservations | Partitioning, clustering, editions |
| S3/GCS Storage | Volume, access patterns | Tiering, lifecycle rules, compaction |
| LLM/AI Inference | Tokens, model size | Model selection, caching, batching |

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/framework.md, concepts/cost-allocation.md |
| **Intermediate** | concepts/cloud-billing.md, concepts/unit-economics.md, concepts/budgets-forecasting.md |
| **Advanced** | patterns/data-pipeline-optimization.md, patterns/warehouse-cost-management.md |
