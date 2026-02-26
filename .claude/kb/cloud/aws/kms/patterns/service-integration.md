# Service Integration Pattern

> **Purpose**: KMS encryption with Lambda, EBS, RDS, Secrets Manager, DynamoDB, and other AWS services
> **MCP Validated**: 2026-02-19

## When to Use

- Enabling encryption at rest for AWS services
- Using customer-managed keys instead of AWS-managed defaults
- Cross-account encrypted resource sharing
- Compliance requirements mandating CMK encryption

## Service Encryption Matrix

| Service | Default Encryption | CMK Support | Key Policy Needed |
|---------|-------------------|:-----------:|:------------------:|
| S3 | SSE-S3 (free) | Yes | `kms:GenerateDataKey`, `kms:Decrypt` |
| EBS | Not encrypted | Yes | `kms:CreateGrant`, `kms:Decrypt` |
| RDS | Not encrypted | Yes | `kms:CreateGrant`, `kms:Decrypt` |
| DynamoDB | AWS-owned (free) | Yes | `kms:Encrypt`, `kms:Decrypt` |
| Secrets Manager | `aws/secretsmanager` | Yes | `kms:Decrypt`, `kms:GenerateDataKey` |
| Lambda (env vars) | `aws/lambda` | Yes | `kms:Decrypt` |
| SQS | Not encrypted | Yes | `kms:GenerateDataKey`, `kms:Decrypt` |
| SNS | Not encrypted | Yes | `kms:GenerateDataKey`, `kms:Decrypt` |
| CloudWatch Logs | Not encrypted | Yes | `kms:Encrypt`, `kms:Decrypt` |

## Lambda Environment Variable Encryption

```hcl
resource "aws_lambda_function" "processor" {
  function_name = "data-processor"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  filename      = "lambda.zip"

  kms_key_arn = module.kms.key_arn

  environment {
    variables = {
      DB_HOST     = "db.example.com"
      DB_PASSWORD = "encrypted-at-rest-by-kms"
    }
  }
}
```

Lambda execution role needs:

```json
{
  "Effect": "Allow",
  "Action": "kms:Decrypt",
  "Resource": "arn:aws:kms:us-east-1:123456789012:key/KEY_ID"
}
```

## EBS Volume Encryption

```hcl
resource "aws_ebs_volume" "data" {
  availability_zone = "us-east-1a"
  size              = 100
  encrypted         = true
  kms_key_id        = module.kms.key_arn
  tags              = var.tags
}

# Default encryption for all new EBS volumes in the account
resource "aws_ebs_encryption_by_default" "enabled" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "custom" {
  key_arn = module.kms.key_arn
}
```

KMS key policy needs for EC2:

```json
{
  "Sid": "AllowEBS",
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::123456789012:role/EC2Role" },
  "Action": [
    "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
    "kms:GenerateDataKey*", "kms:CreateGrant", "kms:DescribeKey"
  ],
  "Resource": "*",
  "Condition": {
    "StringEquals": { "kms:ViaService": "ec2.us-east-1.amazonaws.com" }
  }
}
```

## RDS Encryption

```hcl
resource "aws_db_instance" "main" {
  engine               = "postgres"
  instance_class       = "db.t3.medium"
  allocated_storage    = 50
  storage_encrypted    = true
  kms_key_id           = module.kms.key_arn

  # Note: Cannot enable encryption on existing unencrypted instance
  # Must create encrypted snapshot and restore
}
```

## Secrets Manager with CMK

```python
import boto3

secrets = boto3.client("secretsmanager")
secrets.create_secret(
    Name="prod/database/credentials",
    SecretString='{"username":"admin","password":"secret123"}',
    KmsKeyId="alias/my-app/prod/secrets-key"
)
```

## DynamoDB Encryption

```hcl
resource "aws_dynamodb_table" "data" {
  name         = "application-data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  server_side_encryption {
    enabled     = true
    kms_key_arn = module.kms.key_arn  # CMK; omit for AWS-owned
  }

  attribute {
    name = "pk"
    type = "S"
  }
}
```

## SQS Encryption

```hcl
resource "aws_sqs_queue" "encrypted" {
  name                       = "encrypted-queue"
  kms_master_key_id          = module.kms.key_id
  kms_data_key_reuse_period_seconds = 300  # Cache data key (default 300s)
}
```

Producers need `kms:GenerateDataKey`; consumers need `kms:Decrypt`.

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `kms_key_arn` / `kms_key_id` | AWS-managed | Customer-managed key ARN |
| `kms_data_key_reuse_period_seconds` | 300 | SQS/SNS data key cache (60-86400) |
| `storage_encrypted` | false | RDS, EBS encryption toggle |
| `BucketKeyEnabled` | false | S3 Bucket Key for cost savings |

## See Also

- [S3 Encryption](s3-encryption.md) -- detailed S3 encryption patterns
- [Key Policies](../concepts/key-policies.md) -- ViaService conditions
- [IAM KB](../../iam/) -- service role permissions for KMS
