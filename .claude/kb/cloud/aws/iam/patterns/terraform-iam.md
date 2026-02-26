# Terraform IAM Pattern

> **Purpose**: Codify IAM roles, policies, and permissions boundaries as infrastructure-as-code
> **MCP Validated**: 2026-02-19

## When to Use

- Managing IAM resources across environments (dev/staging/prod)
- Enforcing policy-as-code in CI/CD pipelines
- Creating repeatable, auditable IAM configurations
- Multi-account IAM with Organizations

## Basic Role with Inline Policy

```hcl
data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_perms" {
  statement {
    sid    = "S3ReadAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*",
    ]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${var.function_name}:*"]
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "lambda_inline" {
  name   = "${var.project}-lambda-perms"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_perms.json
}
```

## Using terraform-aws-modules/iam

```hcl
module "lambda_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"

  name = "data-processor-lambda"

  trust_policy_permissions = {
    LambdaService = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }]
    }
  }

  policies = {
    S3ReadOnly = aws_iam_policy.s3_read.arn
    DynamoDB   = aws_iam_policy.dynamo_access.arn
  }

  tags = var.tags
}
```

## Managed Policy (Reusable)

```hcl
resource "aws_iam_policy" "s3_data_lake_read" {
  name        = "${var.project}-s3-datalake-read"
  description = "Read-only access to data lake bucket"
  policy      = data.aws_iam_policy_document.s3_read.json
}

resource "aws_iam_role_policy_attachment" "attach_s3" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.s3_data_lake_read.arn
}
```

**Important**: Use `aws_iam_role_policy_attachment`, never `aws_iam_policy_attachment` (the latter detaches the policy from all other entities).

## Cross-Account Role

```hcl
data "aws_iam_policy_document" "cross_account_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.source_account_id}:role/CI-DeployRole"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [var.org_id]
    }
  }
}

resource "aws_iam_role" "cross_account" {
  name                 = "deploy-target-role"
  assume_role_policy   = data.aws_iam_policy_document.cross_account_trust.json
  max_session_duration = 3600
}
```

## Permissions Boundary in Terraform

```hcl
resource "aws_iam_policy" "developer_boundary" {
  name   = "DeveloperBoundary"
  policy = data.aws_iam_policy_document.boundary.json
}

resource "aws_iam_role" "dev_role" {
  name                 = "developer-role"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  permissions_boundary = aws_iam_policy.developer_boundary.arn
}
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `force_detach_policies` | `false` | Allow role deletion with attached policies |
| `max_session_duration` | `3600` | Max AssumeRole session (seconds) |
| `path` | `/` | IAM path for organization (e.g., `/app/prod/`) |

## Best Practices

1. **Always use `aws_iam_policy_document` data source** -- type-safe, composable, no raw JSON
2. **Never use `aws_iam_policy_attachment`** -- use `aws_iam_role_policy_attachment` instead
3. **Use variables for account IDs and ARNs** -- avoid hardcoding
4. **Tag all IAM resources** -- enables cost allocation and ABAC
5. **Store state remotely** -- S3 + DynamoDB for team collaboration
6. **Plan before apply** -- review IAM changes carefully in `terraform plan`

## See Also

- [Service Roles](service-roles.md) -- practical service role examples
- [Cross-Account Access](cross-account-access.md) -- multi-account patterns
- [Terraform KB](../../../devops-sre/iac/terraform/) -- general Terraform patterns
