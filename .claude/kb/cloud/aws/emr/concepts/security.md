# Security

> **Purpose**: IAM roles, Lake Formation, Kerberos, encryption, VPC security for EMR
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

EMR security covers four pillars: IAM-based access control, data encryption (at rest and in transit), network isolation via VPC, and optional Kerberos authentication. Lake Formation integration adds fine-grained column/row-level access control for data lake tables.

## IAM Roles

EMR requires multiple IAM roles for separation of concerns:

| Role | Service Principal | Purpose |
|------|------------------|---------|
| **EMR Service Role** | `elasticmapreduce.amazonaws.com` | EMR service actions (EC2, S3, CloudWatch) |
| **EC2 Instance Profile** | `ec2.amazonaws.com` | Permissions for cluster EC2 instances |
| **Auto Scaling Role** | `elasticmapreduce.amazonaws.com` | CloudWatch for scaling decisions |
| **Runtime Role** | `elasticmapreduce.amazonaws.com` | Per-step IAM for Lake Formation |

### Minimum Service Role Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances", "ec2:TerminateInstances",
        "ec2:DescribeInstances", "ec2:DescribeSecurityGroups",
        "s3:GetObject", "s3:ListBucket",
        "cloudwatch:PutMetricData",
        "logs:CreateLogGroup", "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

### Runtime Roles (Per-Step IAM)

Runtime roles allow different IAM roles for different EMR steps:

```bash
aws emr add-steps --cluster-id j-XXXXX \
  --steps '[{
    "Name": "Sales ETL",
    "ActionOnFailure": "CONTINUE",
    "HadoopJarStep": {
      "Jar": "command-runner.jar",
      "Args": ["spark-submit", "s3://scripts/sales_etl.py"]
    },
    "ExecutionRoleArn": "arn:aws:iam::role/SalesETLRole"
  }]'
```

## Lake Formation Integration

Lake Formation provides fine-grained access to Glue Catalog tables:

| Access Level | Description |
|-------------|-------------|
| **Database** | Grant access to entire databases |
| **Table** | Grant SELECT/INSERT on specific tables |
| **Column** | Restrict to specific columns |
| **Row** | Row-level filtering via expressions |
| **Cell** | Combine column + row filters |

Requirements for Lake Formation with EMR:
- EMR 6.15+ for Iceberg/Hudi/Delta Lake FGAC
- Runtime roles enabled
- Glue Data Catalog as metastore
- Security configuration with Lake Formation enabled

## Encryption

### At Rest

| Storage | Encryption Method | Key Management |
|---------|------------------|----------------|
| S3 (EMRFS) | SSE-S3, SSE-KMS, CSE-KMS | AWS KMS or S3-managed |
| Local disk (HDFS) | LUKS encryption | KMS-generated key |
| EBS volumes | EBS encryption | AWS KMS |

### In Transit

| Connection | Encryption | Configuration |
|-----------|------------|---------------|
| Node-to-node | TLS 1.2+ | Security configuration |
| EMRFS to S3 | HTTPS (enforced) | Default |
| Application UIs | SSL certificates | Bootstrap action |

Configure encryption via EMR Security Configuration (JSON) with `EnableInTransitEncryption`, `EnableAtRestEncryption`, S3 encryption mode (SSE-KMS), and local disk encryption (AwsKms provider).

## VPC and Network Security

Best practices:
- Launch clusters in **private subnets**
- Use NAT Gateway for outbound internet (package installs)
- EMR-managed security groups for intra-cluster traffic
- Additional security groups for custom rules

| Security Group | Direction | Purpose |
|---------------|-----------|---------|
| EMR-managed (primary) | Inbound 8443 | EMR service communication |
| EMR-managed (core/task) | Inbound 8443 | Node-to-node communication |
| Custom (additional) | Inbound 22 | SSH access (optional, restrict CIDR) |

## Common Mistakes

### Wrong

```bash
# Using default EMR roles with full admin access
aws emr create-cluster --service-role EMR_DefaultRole ...
```

### Correct

```bash
# Custom least-privilege roles
aws emr create-cluster \
  --service-role CustomEMRServiceRole \
  --ec2-attributes InstanceProfile=CustomEMRInstanceProfile \
  ...
```

## Related

- [Cluster Architecture](cluster-architecture.md) -- Node setup
- [Cluster Provisioning](../patterns/cluster-provisioning.md) -- Security config in Terraform
- [AWS IAM KB](../../iam/) -- IAM fundamentals
- [AWS KMS KB](../../kms/) -- Key management
