# Cost Allocation

> **Purpose**: Mapping technology spend to teams, projects, and pipelines via tagging and allocation models
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Cost allocation is the foundation of FinOps visibility. It answers "who spent what and why?" by using tags, labels, and allocation rules to map technology resources to business entities (teams, projects, pipelines). In the FinOps Framework 2025, cost allocation applies across all Scopes -- Public Cloud, SaaS, GenAI, Data Center, and Licensing. For data engineering, this means tracing every dollar to a specific pipeline, query, data product, or LLM inference call.

## Tagging Strategy

### Required Tags for Data Engineering

```yaml
# Minimum tagging standard for all data resources
tags:
  team: "data-engineering"          # Owning team
  project: "customer-analytics"      # Business project
  environment: "prod"                # dev | staging | prod
  pipeline: "bronze-ingest"          # Pipeline or workflow name
  owner: "jane.doe@company.com"      # Point of contact
  cost-center: "CC-4200"             # Finance cost center
  managed-by: "terraform"            # How resource was created
```

### Platform-Specific Tagging

| Platform | Tagging Mechanism | Auto-Tag Support |
|----------|-------------------|------------------|
| AWS | Resource tags (key-value) | AWS Organizations tag policies |
| GCP | Labels (key-value) | Organization policy constraints |
| Snowflake | Warehouse names, resource monitors | Query tags via session params |
| Databricks | Cluster tags, workspace tags | Cluster policies enforce tags |

### Databricks Cluster Tagging

```python
# Enforce tags via cluster policy
{
  "custom_tags.team": {
    "type": "fixed",
    "value": "data-engineering"
  },
  "custom_tags.environment": {
    "type": "allowlist",
    "values": ["dev", "staging", "prod"]
  },
  "custom_tags.pipeline": {
    "type": "regex",
    "pattern": "^[a-z][a-z0-9-]+$"
  }
}
```

## Allocation Models

### Showback vs Chargeback

| Model | Description | When to Use |
|-------|-------------|-------------|
| **Showback** | Report costs to teams, no financial charge | Early FinOps maturity, building awareness |
| **Chargeback** | Charge costs to team budgets | Mature FinOps, engineering accountability |
| **Hybrid** | Showback for shared, chargeback for direct | Most data engineering teams |

### Shared Cost Allocation

Data infrastructure often has shared components. Strategies for allocating shared costs:

| Strategy | Method | Best For |
|----------|--------|----------|
| **Proportional** | Split by usage (queries, compute hours) | Shared warehouses, clusters |
| **Even split** | Divide equally across consumers | Shared storage, networking |
| **Fixed ratio** | Pre-agreed percentages per team | Shared platform services |
| **Direct** | 100% to single owner | Dedicated pipelines, warehouses |

### Handling Untagged Resources

```
Step 1: Identify untagged resources (AWS Cost Explorer, GCP Billing)
Step 2: Set a target: >95% of spend must be tagged
Step 3: Enforce tagging via:
  - IaC policies (Terraform required_tags)
  - Cloud org policies (deny untagged resource creation)
  - Cluster policies (Databricks, EMR)
Step 4: Allocate remaining untagged costs proportionally
```

## Snowflake Cost Allocation

```sql
-- Query cost by warehouse (proxy for team cost)
SELECT
    warehouse_name,
    SUM(credits_used) AS total_credits,
    SUM(credits_used) * 3.00 AS estimated_cost_usd  -- adjust rate
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_credits DESC;
```

**Best practice:** One warehouse per team/workload type, named with team prefix (e.g., `DE_ETL_MEDIUM`, `ANALYTICS_ADHOC_SMALL`).

## Common Mistakes

### Wrong

```text
- Tag resources manually after creation
- Use inconsistent tag keys (Team vs team vs TEAM)
- Ignore shared/platform costs in allocation
```

### Correct

```text
- Enforce tags at creation via IaC and policies
- Standardize tag keys in a central tagging policy document
- Allocate shared costs using proportional usage metrics
```

## Related

- [Framework](framework.md) -- Cost allocation is the core of the Inform phase
- [Unit Economics](unit-economics.md) -- Turn allocated costs into business metrics
- [Governance](governance.md) -- Enforcing tagging compliance
