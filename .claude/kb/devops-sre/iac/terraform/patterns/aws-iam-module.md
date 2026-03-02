# AWS IAM Module

> **Purpose**: Reusable IAM roles, policies, and OIDC federation for least-privilege access
> **MCP Validated**: 2026-02-19
> **Provider**: hashicorp/aws ~> 5.0

## Service Role Pattern

Create roles for AWS services (Lambda, ECS, etc.) with least-privilege policies.

### variables.tf

```hcl
variable "role_name" {
  description = "IAM role name"
  type        = string
}

variable "trusted_service" {
  description = "AWS service principal (e.g., lambda.amazonaws.com)"
  type        = string
}

variable "policy_statements" {
  description = "IAM policy statements"
  type = list(object({
    sid       = string
    effect    = optional(string, "Allow")
    actions   = list(string)
    resources = list(string)
  }))
}

variable "managed_policy_arns" {
  description = "ARNs of managed policies to attach"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
```

### main.tf

```hcl
resource "aws_iam_role" "this" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = var.trusted_service }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "inline" {
  name = "${var.role_name}-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for stmt in var.policy_statements : {
        Sid      = stmt.sid
        Effect   = stmt.effect
        Action   = stmt.actions
        Resource = stmt.resources
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}
```

### outputs.tf

```hcl
output "role_arn" {
  value = aws_iam_role.this.arn
}

output "role_name" {
  value = aws_iam_role.this.name
}
```

## OIDC Provider for GitHub Actions

Enables keyless authentication from GitHub Actions to AWS.

```hcl
# One-time OIDC provider setup
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

# Role for GitHub Actions
resource "aws_iam_role" "github_deploy" {
  name = "github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })
}
```

## Cross-Account Role

```hcl
resource "aws_iam_role" "cross_account" {
  name = "cross-account-data-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${var.trusted_account_id}:root" }
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.external_id
        }
      }
    }]
  })
}
```

## Usage: Lambda with S3 + Secrets Access

```hcl
module "parser_role" {
  source = "./modules/aws-iam-role"

  role_name       = "file-parser-role"
  trusted_service = "lambda.amazonaws.com"

  policy_statements = [
    {
      sid       = "ReadInputBucket"
      actions   = ["s3:GetObject", "s3:ListBucket"]
      resources = [module.input.bucket_arn, "${module.input.bucket_arn}/*"]
    },
    {
      sid       = "WriteOutputBucket"
      actions   = ["s3:PutObject"]
      resources = ["${module.output.bucket_arn}/*"]
    },
    {
      sid       = "ReadSecrets"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [aws_secretsmanager_secret.api_key.arn]
    }
  ]

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}
```

## Related

- [AWS IAM KB](../../../../cloud/aws/iam/) | [Lambda Module](./aws-lambda-module.md) | [GCP IAM Module](./iam-module.md)
