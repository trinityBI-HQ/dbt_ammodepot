# Terraform Setup Pattern

> **Purpose**: Infrastructure as Code for Secrets Manager with rotation, replication, and policies
> **MCP Validated**: 2026-02-19

## When to Use

- Managing secrets as part of IaC pipelines
- Multi-environment secret provisioning
- Automated rotation configuration
- Cross-region replication setup

## Implementation

```hcl
# --- Secret with KMS encryption ---
resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.environment}/${var.project}/db-credentials"
  description             = "Database credentials for ${var.project}"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    port     = var.db_port
    engine   = "postgres"
    dbname   = var.db_name
  })
}

# --- Rotation configuration ---
resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 30
  }
}

# --- Resource policy ---
resource "aws_secretsmanager_secret_policy" "db_credentials" {
  secret_arn = aws_secretsmanager_secret.db_credentials.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = var.app_role_arn }
        Action    = ["secretsmanager:GetSecretValue"]
        Resource  = "*"
      }
    ]
  })
}

# --- Cross-region replication ---
resource "aws_secretsmanager_secret" "replicated" {
  name       = "${var.environment}/${var.project}/api-key"
  kms_key_id = aws_kms_key.secrets.arn

  replica {
    region     = "us-west-2"
    kms_key_id = var.replica_kms_key_arn
  }

  recovery_window_in_days = 7
}
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `recovery_window_in_days` | 30 | Days before permanent deletion (7-30, or 0 to force) |
| `kms_key_id` | `aws/secretsmanager` | KMS key ARN or alias |
| `automatically_after_days` | N/A | Rotation frequency |
| `force_overwrite_replica_secret` | false | Overwrite existing replica |

## Variables

```hcl
variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
}

variable "project" {
  type        = string
  description = "Project name for secret path prefix"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_name" {
  type = string
}

variable "app_role_arn" {
  type        = string
  description = "IAM role ARN allowed to read the secret"
}

variable "replica_kms_key_arn" {
  type        = string
  default     = null
  description = "KMS key ARN in the replica region"
}
```

## Module Usage (lgallard/terraform-aws-secrets-manager)

```hcl
module "secrets" {
  source  = "lgallard/secrets-manager/aws"
  version = "~> 0.11"

  secrets = {
    "prod/myapp/db-credentials" = {
      description      = "Database credentials"
      secret_key_value = {
        username = "admin"
        password = "s3cure!"
        host     = "db.example.com"
      }
      kms_key_id              = aws_kms_key.secrets.arn
      recovery_window_in_days = 30
    }
  }

  tags = { Environment = "prod" }
}
```

## See Also

- [Encryption and KMS](../concepts/encryption-kms.md)
- [Replication](../concepts/replication.md)
- [Cross-Account Access](../patterns/cross-account-access.md)
