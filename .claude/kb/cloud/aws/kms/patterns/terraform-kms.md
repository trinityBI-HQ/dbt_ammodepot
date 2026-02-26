# Terraform KMS Pattern

> **Purpose**: Provision and manage KMS keys, aliases, grants, and policies as infrastructure-as-code
> **MCP Validated**: 2026-02-19

## When to Use

- Provisioning KMS keys across environments (dev/staging/prod)
- Managing key policies and grants as code for audit compliance
- Creating multi-region key infrastructure
- Automating key lifecycle with rotation and aliases

## Using terraform-aws-modules/kms

```hcl
module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 4.0"

  description             = "Application data encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  is_enabled              = true
  key_usage               = "ENCRYPT_DECRYPT"
  multi_region            = false

  # Policy: separate admin from usage
  enable_default_policy = true
  key_owners            = [data.aws_caller_identity.current.arn]
  key_administrators    = ["arn:aws:iam::${var.account_id}:role/KeyAdmin"]
  key_users             = ["arn:aws:iam::${var.account_id}:role/AppRole"]
  key_service_users     = ["arn:aws:iam::${var.account_id}:role/EC2Role"]

  # Aliases
  aliases = ["${var.project}/${var.environment}/data-key"]

  # Grants
  grants = {
    lambda_processor = {
      grantee_principal = aws_iam_role.lambda.arn
      operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
      constraints = [{
        encryption_context_equals = {
          Environment = var.environment
        }
      }]
    }
  }

  tags = var.tags
}
```

## Native Terraform Resources

```hcl
resource "aws_kms_key" "data" {
  description             = "${var.project} data encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.key_policy.json
  tags                    = var.tags
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.project}/${var.environment}/data-key"
  target_key_id = aws_kms_key.data.key_id
}

data "aws_iam_policy_document" "key_policy" {
  # Enable IAM policies
  statement {
    sid    = "EnableIAMPolicies"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Key administrators
  statement {
    sid    = "KeyAdmins"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = var.key_admin_arns
    }
    actions = [
      "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
      "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
      "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
      "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
    ]
    resources = ["*"]
  }

  # Key users
  statement {
    sid    = "KeyUsers"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = var.key_user_arns
    }
    actions = [
      "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
      "kms:GenerateDataKey*", "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}
```

## Multi-Region Keys in Terraform

```hcl
module "kms_primary" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 4.0"

  description         = "Primary multi-region key"
  enable_key_rotation = true
  multi_region        = true

  key_administrators = var.admin_arns
  key_users          = var.user_arns
  aliases            = ["${var.project}/primary"]
  tags               = var.tags
}

module "kms_replica" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 4.0"

  providers = { aws = aws.secondary }

  create_replica  = true
  primary_key_arn = module.kms_primary.key_arn

  key_administrators = var.admin_arns
  key_users          = var.user_arns
  aliases            = ["${var.project}/replica"]
  tags               = var.tags
}
```

## S3 Encryption with KMS Key

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.kms.key_arn
    }
    bucket_key_enabled = true
  }
}
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `deletion_window_in_days` | 30 | Waiting period before key deletion (7-30) |
| `enable_key_rotation` | `false` | Enable automatic annual rotation |
| `multi_region` | `false` | Create as multi-region primary |
| `key_usage` | `ENCRYPT_DECRYPT` | Or `SIGN_VERIFY`, `GENERATE_VERIFY_MAC` |
| `customer_master_key_spec` | `SYMMETRIC_DEFAULT` | Key algorithm spec |

## Best Practices

1. **Always enable key rotation** for customer-managed symmetric keys
2. **Use the module** (`terraform-aws-modules/kms`) over raw resources for policy management
3. **Separate admin and user principals** in key policies
4. **Use `aws_iam_policy_document`** data source for type-safe policies
5. **Enable Bucket Key** when using SSE-KMS for S3 (99% cost reduction)
6. **Tag all keys** for cost allocation and ABAC

## See Also

- [Key Policies](../concepts/key-policies.md) -- policy structure details
- [Multi-Region Keys](../concepts/multi-region-keys.md) -- replication concepts
- [Terraform KB](../../../devops-sre/iac/terraform/) -- general Terraform patterns
