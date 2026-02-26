# AWS (Amazon Web Services)

> **Category:** Cloud | **Subcategory:** AWS

AWS is the most mature and feature-rich cloud provider with the largest ecosystem. This KB covers core AWS services for data engineering, serverless, and security workflows.

## Technologies

| Technology | Path | Description |
|-----------|------|-------------|
| **S3** | [s3/](s3/) | Scalable object storage for data lakes, backups, and hosting |
| **IAM** | [iam/](iam/) | Identity and access management -- roles, policies, federation |
| **Glue** | [glue/](glue/) | Serverless ETL, Data Catalog, crawlers, and data quality |
| **S3 Tables** | [s3-tables/](s3-tables/) | Apache Iceberg tables managed by S3 |
| **Athena** | [athena/](athena/) | Serverless SQL queries over S3 data |
| **KMS** | [kms/](kms/) | Encryption key management -- data keys, envelope encryption, rotation |
| **CloudWatch** | [cloudwatch/](cloudwatch/) | Full-stack observability -- metrics, logs, alarms, dashboards, synthetics |
| **Secrets Manager** | [secrets-manager/](secrets-manager/) | Secret storage, rotation, and cross-account sharing |

## Decision Framework

| Need | Service |
|------|---------|
| Store files/objects | S3 |
| Control who accesses what | IAM |
| Query data in S3 with SQL | Athena |
| ETL jobs and data catalog | Glue |
| Managed Iceberg tables | S3 Tables |
| Encrypt data and manage keys | KMS |
| Monitor resources and apps | CloudWatch |
| Credential/secret management | Secrets Manager |
| Infrastructure as Code | See [Terraform KB](../../devops-sre/iac/terraform/) |

## Cross-References

- **GCP**: See [../gcp/](../gcp/) for Google Cloud equivalent services
- **Terraform**: See [../../devops-sre/iac/terraform/](../../devops-sre/iac/terraform/) for multi-cloud IaC
- **Lambda agents**: See `aws-lambda-architect`, `lambda-builder`, `aws-deployer` agents

## Adding New AWS Services

Use `/create-kb cloud/aws/<service-name>` to scaffold a new AWS service KB.
