# FinOps (Cloud Financial Operations) Knowledge Base

> **Last Updated:** 2026-02-13
> **Maintained By:** Claude Code Lab Team

## Overview

FinOps (Cloud Financial Operations) is a cultural practice and operational framework that brings financial accountability to the variable spend model of cloud computing. This subcategory focuses specifically on cost optimization for data engineering workloads -- pipelines, warehouses, storage, and compute.

## Philosophy

**Build cost-aware data systems that are:**
- **Visible**: Every dollar traced to a team, pipeline, or query
- **Optimized**: Right-sized compute, tiered storage, commitment discounts
- **Governed**: Budgets, alerts, and approval workflows prevent waste
- **Measured**: Unit economics tie cost to business value

**Avoid:**
- Running pipelines without cost attribution
- Over-provisioned clusters left running 24/7
- Ignoring storage lifecycle management
- Treating cloud spend as a fixed cost

## Technologies

### [FinOps](finops/)

**What it does:** Framework and practices for managing cloud costs across data engineering infrastructure (compute, storage, warehouses, pipelines).

**When to use:**
- Cloud spend on data infrastructure exceeds budget targets
- Teams lack visibility into per-pipeline or per-query costs
- Need to optimize Spark/Databricks clusters, Snowflake warehouses, or BigQuery slots
- Building cost governance for growing data platforms

**Key capabilities:**
- FinOps Framework phases: Inform, Optimize, Operate
- Cost allocation via tagging, showback, and chargeback
- Unit economics for data workloads (cost/query, cost/pipeline, cost/GB)
- Cloud-specific optimization (AWS Savings Plans, GCP CUDs, Snowflake credits)

**Alternatives:** Ad-hoc cost monitoring (insufficient at scale), vendor-specific tools only (lacks cross-platform view)

## Decision Framework

### When to Invest in FinOps?

| Signal | Action | Priority |
|--------|--------|----------|
| Monthly cloud spend > $10K | Start Inform phase | High |
| No cost attribution by team/project | Implement tagging strategy | Critical |
| Warehouse/compute costs growing > 20% MoM | Right-size and optimize | High |
| Storage costs exceed compute costs | Implement lifecycle policies | Medium |
| Finance asks "where does the money go?" | Build showback dashboards | High |

### FinOps Maturity Model

| Level | Description | Focus |
|-------|-------------|-------|
| **Crawl** | Basic visibility, reactive optimization | Tagging, budgets, simple alerts |
| **Walk** | Proactive optimization, team accountability | Unit economics, chargeback, automation |
| **Run** | Continuous optimization, engineering culture | Real-time governance, AI-driven optimization |

## Cross-References

| Topic | KB Path | Relevance |
|-------|---------|-----------|
| AWS S3, IAM, Glue, Athena | [cloud/aws/](../../cloud/aws/) | AWS-specific cost optimization |
| GCP BigQuery, Cloud Run | [cloud/gcp/](../../cloud/gcp/) | GCP-specific cost optimization |
| Snowflake | [data-platforms/snowflake/](../data-platforms/snowflake/) | Warehouse credit optimization |
| Apache Spark | Data processing optimization | Cluster right-sizing, spot instances |
| Terraform | [devops-sre/iac/terraform/](../../devops-sre/iac/terraform/) | IaC for cost guardrails |
| Apache Iceberg | [table-formats/iceberg/](../table-formats/iceberg/) | Storage compaction and optimization |

## Related Knowledge

- **Cloud Infrastructure**: See [cloud/](../../cloud/) for AWS/GCP service details
- **Data Platforms**: See [data-platforms/](../data-platforms/) for Snowflake optimization
- **Table Formats**: See [table-formats/](../table-formats/) for Iceberg compaction patterns
- **Observability**: See [observability/](../observability/) for Elementary cost-of-quality

---

**Inform, Optimize, Operate -- every data dollar accounted for.**
