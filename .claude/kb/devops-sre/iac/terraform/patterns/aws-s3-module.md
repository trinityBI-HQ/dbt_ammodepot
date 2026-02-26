# AWS S3 Bucket Module

> **Purpose**: Reusable S3 bucket with encryption, versioning, lifecycle rules, and access controls
> **MCP Validated**: 2026-02-19
> **Provider**: hashicorp/aws ~> 5.0

## Module Structure

```text
modules/aws-s3-bucket/
├── main.tf
├── variables.tf
├── outputs.tf
└── versions.tf
```

## variables.tf

```hcl
variable "bucket_name" {
  description = "Name of the S3 bucket (globally unique)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_versioning" {
  description = "Enable bucket versioning"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow bucket deletion with objects"
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for object transitions"
  type = list(object({
    id                     = string
    prefix                 = optional(string, "")
    transition_days        = optional(number, 90)
    transition_class       = optional(string, "STANDARD_IA")
    expiration_days        = optional(number, null)
    noncurrent_expiration  = optional(number, 30)
  }))
  default = []
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
```

## main.tf

```hcl
resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = "Enabled"

      filter {
        prefix = rule.value.prefix
      }

      transition {
        days          = rule.value.transition_days
        storage_class = rule.value.transition_class
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      noncurrent_version_expiration {
        noncurrent_days = rule.value.noncurrent_expiration
      }
    }
  }
}
```

## outputs.tf

```hcl
output "bucket_id" {
  description = "Bucket name"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Bucket regional domain name"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
```

## Usage

```hcl
module "data_lake" {
  source = "./modules/aws-s3-bucket"

  bucket_name = "myproject-${var.environment}-data-lake"
  environment = var.environment

  lifecycle_rules = [
    {
      id               = "archive-old-data"
      prefix           = "raw/"
      transition_days  = 90
      transition_class = "GLACIER"
      expiration_days  = 365
    }
  ]
}
```

## Related

- [AWS S3 KB](../../../../cloud/aws/s3/) | [IAM Module](./aws-iam-module.md) | [GCS Module](./gcs-module.md)
