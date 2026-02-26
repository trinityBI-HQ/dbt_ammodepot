# Security and Access Control

> **Purpose**: IAM policies, table bucket policies, encryption, and Lake Formation integration
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

S3 Tables uses the `s3tables` IAM namespace (separate from `s3`). Access is managed via IAM policies, table bucket policies, individual table policies, and Lake Formation for fine-grained column/row-level security.

## IAM Namespace

S3 Tables actions use `s3tables:*`, not `s3:*`:

| Action | Purpose |
|--------|---------|
| `s3tables:CreateTableBucket` | Create table bucket |
| `s3tables:CreateNamespace` | Create namespace |
| `s3tables:CreateTable` | Create table |
| `s3tables:GetTable` | Get table details |
| `s3tables:GetTableMetadataLocation` | Read Iceberg metadata (needed for queries) |
| `s3tables:PutTableMaintenanceConfiguration` | Configure compaction/snapshots |
| `s3tables:DeleteTable` | Delete table |
| `s3tables:PutTablePolicy` | Attach resource policy to table |
| `s3tables:PutTableBucketPolicy` | Attach policy to table bucket |

## IAM Policy Example

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAnalyticsTeamRead",
      "Effect": "Allow",
      "Action": [
        "s3tables:GetTable",
        "s3tables:GetTableMetadataLocation",
        "s3tables:ListTables",
        "s3tables:ListNamespaces"
      ],
      "Resource": [
        "arn:aws:s3tables:us-east-1:123456789012:bucket/analytics-bucket",
        "arn:aws:s3tables:us-east-1:123456789012:bucket/analytics-bucket/*"
      ]
    },
    {
      "Sid": "AllowWriteToSalesNamespace",
      "Effect": "Allow",
      "Action": [
        "s3tables:CreateTable",
        "s3tables:UpdateTableMetadataLocation"
      ],
      "Resource": "arn:aws:s3tables:us-east-1:123456789012:bucket/analytics-bucket/*"
    }
  ]
}
```

## Table Bucket Policy

Resource-based policy attached to the table bucket:

```python
import json
import boto3

s3tables = boto3.client("s3tables")

policy = {
    "Version": "2012-10-17",
    "Statement": [{
        "Sid": "CrossAccountRead",
        "Effect": "Allow",
        "Principal": {"AWS": "arn:aws:iam::999888777666:root"},
        "Action": ["s3tables:GetTable", "s3tables:GetTableMetadataLocation"],
        "Resource": "arn:aws:s3tables:us-east-1:123456789012:bucket/my-bucket/*",
    }],
}

s3tables.put_table_bucket_policy(
    tableBucketARN="arn:aws:s3tables:us-east-1:123456789012:bucket/my-bucket",
    resourcePolicy=json.dumps(policy),
)
```

## Encryption

| Type | Default | KMS Requirement |
|------|---------|----------------|
| SSE-S3 (AES-256) | Yes (default) | None |
| SSE-KMS | Optional | Must grant S3 Tables maintenance principal access |

```bash
# Create bucket with SSE-KMS
aws s3tables create-table-bucket \
  --name my-secure-bucket \
  --encryption-configuration '{
    "sseAlgorithm": "aws:kms",
    "kmsKeyArn": "arn:aws:kms:us-east-1:123456789012:key/my-key-id"
  }'
```

**Important**: For SSE-KMS, the KMS key policy must grant the S3 Tables service principal (`s3tables.amazonaws.com`) permissions for `kms:Decrypt` and `kms:GenerateDataKey` to enable automatic maintenance operations.

## Lake Formation Integration

When integrated with SageMaker Lakehouse, Lake Formation provides fine-grained access:

| Level | Control |
|-------|---------|
| Catalog | Access to `s3tablescatalog` |
| Database | Access to specific namespaces |
| Table | Access to specific tables |
| Column | Column-level permissions |
| Row/Cell | Row-filter and cell-level security |

Integration creates a federated catalog `s3tablescatalog` in Glue Data Catalog:
- Table buckets → multi-level catalogs
- Namespaces → databases
- Tables → tables in Data Catalog

## Managed IAM Policy Update (Dec 2025)

The `AmazonS3TablesFullAccess` managed policy was updated in Dec 2025 to include permissions for cross-region and cross-account replication. If you use this managed policy, replication permissions are automatically available. For custom policies, add `s3tables:CreateTableBucketReplication` and `s3tables:GetTableBucketReplication` actions.

## Maintenance Principal Access

S3 Tables runs automated maintenance (compaction, snapshots) using an internal service principal. When using SSE-KMS, this principal needs KMS access:

```json
{
  "Sid": "AllowS3TablesMaintenanceAccess",
  "Effect": "Allow",
  "Principal": {"Service": "s3tables.amazonaws.com"},
  "Action": ["kms:Decrypt", "kms:GenerateDataKey"],
  "Resource": "*",
  "Condition": {
    "StringEquals": {"aws:SourceAccount": "123456789012"}
  }
}
```

## Related

- [table-buckets-namespaces](table-buckets-namespaces.md)
- [../patterns/analytics-integration](../patterns/analytics-integration.md)
- [../../s3/concepts/security-access](../../s3/concepts/security-access.md)
