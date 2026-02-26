# FinOps Knowledge Base

> **Purpose**: Financial operations framework for technology cost optimization (cloud, SaaS, GenAI, data centers)
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/framework.md](concepts/framework.md) | FinOps Framework phases: Inform, Optimize, Operate |
| [concepts/cost-allocation.md](concepts/cost-allocation.md) | Tagging, showback, chargeback, cost centers |
| [concepts/cloud-billing.md](concepts/cloud-billing.md) | AWS/GCP billing models, reservations, savings plans |
| [concepts/unit-economics.md](concepts/unit-economics.md) | Cost per query, per pipeline run, per GB processed |
| [concepts/budgets-forecasting.md](concepts/budgets-forecasting.md) | Budget alerts, forecasting models, anomaly detection |
| [concepts/governance.md](concepts/governance.md) | Policies, approval workflows, guardrails, waste detection |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/data-pipeline-optimization.md](patterns/data-pipeline-optimization.md) | Spark/Databricks cluster optimization, spot instances |
| [patterns/warehouse-cost-management.md](patterns/warehouse-cost-management.md) | Snowflake credits, BigQuery slots, warehouse sizing |
| [patterns/storage-optimization.md](patterns/storage-optimization.md) | S3 lifecycle policies, storage classes, data tiering |
| [patterns/monitoring-alerting.md](patterns/monitoring-alerting.md) | Cost dashboards, alerts, anomaly detection, automation |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables for cost optimization

---

## What is FinOps?

FinOps is an operational framework that brings financial accountability to the variable spend model of technology. Originally focused on public cloud, the **FinOps Framework 2025** expanded to cover five "Scopes": Public Cloud, SaaS, Data Centers, GenAI, and Licensing. The word "Cloud" has been formally removed from capability names, reflecting that FinOps now applies to all technology spending. For data engineering teams, this means understanding, optimizing, and governing the cost of pipelines, warehouses, storage, compute, SaaS platforms, and AI/LLM workloads.

## The FinOps Lifecycle

```
    +----------+     +----------+     +---------+
    |  INFORM  | --> | OPTIMIZE | --> | OPERATE |
    +----------+     +----------+     +---------+
         ^                                 |
         +---------------------------------+
              Continuous iteration
```

- **Inform**: Visibility into who spends what, where, and why
- **Optimize**: Right-size, commit, architect for efficiency
- **Operate**: Govern, automate, and enforce policies

## FinOps Framework 2025: Scopes

The 2025 framework update introduced **Scopes** to apply FinOps practices beyond public cloud:

| Scope | Examples | Data Engineering Relevance |
|-------|----------|---------------------------|
| **Public Cloud** | AWS, GCP, Azure | Core infrastructure for data pipelines |
| **SaaS** | Snowflake, Databricks, Fivetran, Salesforce | Major data platform cost centers |
| **GenAI** | OpenAI, Bedrock, Vertex AI, Anthropic | LLM/AI pipeline costs (tokens, inference) |
| **Data Center** | On-prem Hadoop, Spark clusters | Hybrid deployments |
| **Licensing** | Oracle, SAP, Tableau | Software license cost management |

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Scopes** | Five domains where FinOps applies: Public Cloud, SaaS, GenAI, Data Center, Licensing |
| **Cost Allocation** | Mapping technology spend to teams, projects, and pipelines via tags |
| **Unit Economics** | Cost per business unit (query, pipeline run, GB processed, LLM token) |
| **Commitment Discounts** | Reserved Instances, Savings Plans, CUDs for predictable workloads |
| **Right-Sizing** | Matching compute resources to actual workload requirements |
| **Storage Tiering** | Moving data to cheaper storage classes based on access patterns |
| **Waste Detection** | Finding idle resources, unused storage, and over-provisioned compute |

## Data Engineering Focus

This KB emphasizes cost optimization specific to data workloads across all scopes:

| Workload | Scope | Key Cost Drivers | Optimization Levers |
|----------|-------|------------------|---------------------|
| Spark/Databricks | SaaS | Cluster size, DBUs, spot usage | Right-size, autoscale, Jobs clusters |
| Snowflake | SaaS | Credits, warehouse size, auto-suspend | Warehouse sizing, query optimization |
| BigQuery | Public Cloud | Bytes scanned, slot reservations | Partitioning, clustering, editions |
| S3/GCS Storage | Public Cloud | Volume, access patterns, lifecycle | Tiering, lifecycle rules, compaction |
| Data Pipelines | Public Cloud | Compute time, scheduling frequency | Schedule optimization, incremental |
| LLM/AI Inference | GenAI | Tokens, model size, batch vs real-time | Model selection, caching, batching |

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/framework.md, concepts/cost-allocation.md |
| **Intermediate** | concepts/cloud-billing.md, concepts/unit-economics.md, concepts/budgets-forecasting.md |
| **Advanced** | patterns/data-pipeline-optimization.md, patterns/warehouse-cost-management.md |

---

## Project Context

This KB supports FinOps practices for data engineering teams:
- FinOps Framework 2025 with five Scopes (Public Cloud, SaaS, GenAI, Data Center, Licensing)
- Cost optimization across AWS, GCP, Snowflake, Databricks, and GenAI platforms
- Unit economics for data pipelines, queries, and LLM inference
- Tagging strategies and cost governance for data platforms
- Budget forecasting and anomaly detection
