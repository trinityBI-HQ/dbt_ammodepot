# Multi-Cloud Patterns

> **Status:** Placeholder - Knowledge base content coming soon

This folder is reserved for multi-cloud architecture patterns and best practices.

## Why Multi-Cloud?

Multi-cloud strategies leverage services from multiple cloud providers to avoid vendor lock-in, optimize costs, and use best-of-breed services. This requires careful abstraction layers, portable tooling, and standardized deployment practices.

**When to use multi-cloud:**
- Regulatory requirements mandate data sovereignty across regions
- Best-of-breed needs (e.g., GCP BigQuery + AWS Lambda)
- Risk mitigation against single-provider outages
- M&A integration of teams on different clouds

## Related Technologies

- **GCP**: See [../gcp/](../gcp/) for Google Cloud services
- **AWS**: See [../aws/](../aws/) for Amazon Web Services
- **Azure**: See [../azure/](../azure/) for Microsoft Azure
- **Terraform**: See [../../devops-sre/iac/terraform/](../../devops-sre/iac/terraform/) for cloud-agnostic IaC

## To Add Content Here

Use `/create-kb cloud/multi-cloud-patterns` to scaffold this domain.
