# Governance

> **Purpose**: Policies, approval workflows, guardrails, and waste detection for technology cost control
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

FinOps governance establishes the rules, workflows, and automation that prevent cost waste and enforce financial accountability across all Scopes (Public Cloud, SaaS, GenAI, Data Center, Licensing). For data engineering, this means cluster policies, warehouse guardrails, tagging enforcement, LLM usage limits, and approval workflows that balance engineering velocity with cost discipline.

## Policy Categories

### Compute Policies

| Policy | Implementation | Platform |
|--------|---------------|----------|
| Max cluster size | Cluster policy: max workers | Databricks |
| Required spot ratio | Cluster policy: spot = 80%+ | Databricks, EMR |
| Auto-terminate idle | Terminate after 30 min idle | Databricks, EMR |
| Max warehouse size | Account-level restriction | Snowflake |
| Auto-suspend timeout | Set to 60 seconds | Snowflake |
| Instance type allowlist | Limit to cost-effective types | AWS, GCP |

### Databricks Cluster Policy Example

```json
{
  "name": "data-eng-cost-optimized",
  "definition": {
    "autoscale.min_workers": {"type": "range", "minValue": 1, "maxValue": 2},
    "autoscale.max_workers": {"type": "range", "minValue": 2, "maxValue": 20},
    "autotermination_minutes": {"type": "range", "minValue": 10, "maxValue": 60},
    "spark_conf.spark.databricks.cluster.profile": {
      "type": "fixed", "value": "serverless", "hidden": true
    },
    "aws_attributes.availability": {
      "type": "fixed", "value": "SPOT_WITH_FALLBACK"
    },
    "node_type_id": {
      "type": "allowlist",
      "values": ["i3.xlarge", "i3.2xlarge", "r5.xlarge", "r5.2xlarge"]
    },
    "custom_tags.team": {"type": "fixed", "value": "data-engineering"},
    "custom_tags.environment": {
      "type": "allowlist", "values": ["dev", "staging", "prod"]
    }
  }
}
```

### Storage Policies

| Policy | Rule | Platform |
|--------|------|----------|
| Lifecycle rules required | All buckets must have lifecycle config | AWS S3, GCS |
| Max retention for dev data | Auto-delete after 30 days | S3, GCS |
| No public access | Block public access by default | S3, GCS |
| Versioning with expiry | Keep 3 versions, expire after 90 days | S3 |

### Tagging Enforcement

```hcl
# Terraform: Enforce required tags on all resources
variable "required_tags" {
  default = {
    team        = "data-engineering"
    environment = "prod"
    project     = "customer-analytics"
    owner       = "data-team@company.com"
    cost-center = "CC-4200"
  }
}

# AWS SCP: Deny resource creation without required tags
resource "aws_organizations_policy" "require_tags" {
  name    = "require-cost-tags"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyUntaggedResources"
      Effect    = "Deny"
      Action    = ["ec2:RunInstances", "s3:CreateBucket", "emr:RunJobFlow"]
      Resource  = "*"
      Condition = {
        "StringEquals" = { "aws:RequestTag/team" = "" }
      }
    }]
  })
}
```

## Waste Detection

### Common Waste Categories

| Waste Type | Detection Method | Estimated Savings |
|------------|-----------------|-------------------|
| Idle clusters (running, no jobs) | Utilization < 5% for 1h+ | 15-30% of compute |
| Over-provisioned warehouses | Avg query < 30s on Large | 30-50% on warehouse |
| Orphan storage (no readers) | No access for 90+ days | 10-20% of storage |
| Dev resources running 24/7 | Non-prod running weekends | 60-70% of dev compute |
| Duplicate data copies | Same data in multiple locations | 20-40% of storage |
| Uncompacted Delta/Iceberg | Small files, no maintenance | 10-30% of query cost |

### Automation for Waste Detection

```python
# Example: Detect idle Snowflake warehouses
IDLE_WAREHOUSE_QUERY = """
SELECT
    warehouse_name,
    MAX(end_time) AS last_used,
    DATEDIFF('hour', MAX(end_time), CURRENT_TIMESTAMP()) AS hours_idle
FROM snowflake.account_usage.warehouse_metering_history
GROUP BY warehouse_name
HAVING hours_idle > 24
ORDER BY hours_idle DESC;
"""
```

## Approval Workflows

| Resource Request | Threshold | Approval Required |
|-----------------|-----------|-------------------|
| New cluster > 10 nodes | Always | Team lead |
| Snowflake warehouse > Medium | Always | Data eng manager |
| New S3 bucket | Always | Must use IaC (Terraform) |
| Spot override (use on-demand) | > $100/day | Team lead + FinOps |
| New Savings Plan purchase | Any | FinOps team + Finance |

## Governance Maturity

| Level | Policies | Guardrails | Detection |
|-------|----------|------------|-----------|
| **Crawl** | Documented standards | Manual enforcement | Monthly manual review |
| **Walk** | IaC-enforced policies | Cluster/warehouse policies | Weekly automated scans |
| **Run** | Auto-remediation | Real-time prevention | Continuous monitoring |

## Related

- [Framework](framework.md) -- Governance is the core of the Operate phase
- [Cost Allocation](cost-allocation.md) -- Tagging enforcement enables allocation
- [Budgets and Forecasting](budgets-forecasting.md) -- Budget limits feed governance
