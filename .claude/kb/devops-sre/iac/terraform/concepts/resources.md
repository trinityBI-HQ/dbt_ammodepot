# Resources and Data Sources

> **Purpose**: Fundamental building blocks of Terraform configurations
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Resources are the most important element in Terraform. Each resource block describes one or more infrastructure objects. Data sources query existing infrastructure without managing it.

## Resources

### Basic Syntax

```hcl
# GCP example
resource "google_storage_bucket" "data" {
  name          = "${var.project}-data-${var.environment}"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true
  versioning { enabled = true }
}

# AWS example
resource "aws_s3_bucket" "data" {
  bucket = "${var.project}-data-${var.environment}"
  tags   = local.common_tags
}
```

### Resource Behavior

| Action | When |
|--------|------|
| Create | Resource not in state |
| Update | Config differs from state |
| Replace | Immutable attribute changed |
| Destroy | Resource removed from config |

### Meta-Arguments

```hcl
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  depends_on = [aws_internet_gateway.main]

  lifecycle {
    prevent_destroy       = true
    create_before_destroy = true
    ignore_changes        = [tags["LastModified"]]
  }
}
```

## Data Sources

Query existing resources without managing them:

```hcl
# GCP
data "google_project" "current" {
  project_id = var.gcp_project_id
}

# AWS
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Use in resource
resource "aws_s3_bucket" "logs" {
  bucket = "logs-${data.aws_caller_identity.current.account_id}"
}
```

Common data sources: `google_project`/`aws_caller_identity` (identity), `google_secret_manager_secret_version`/`aws_secretsmanager_secret_version` (secrets), `google_storage_bucket`/`aws_s3_bucket` (existing buckets).
## Resource Dependencies

### Implicit (Recommended)

```hcl
resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name  # implicit dependency
  policy_arn = aws_iam_policy.lambda.arn  # implicit dependency
}
```

### Explicit (When Needed)

```hcl
resource "google_cloud_run_service" "api" {
  depends_on = [
    google_project_service.run,
    google_project_service.secretmanager
  ]
  # ...
}
```

## Ephemeral Resources (1.10+)

Resources whose values are **never persisted** in state or plan files. Use for secrets, short-lived tokens, and temporary credentials:

```hcl
ephemeral "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = aws_secretsmanager_secret.db.id
}

# Use the ephemeral value (not stored in state)
resource "aws_db_instance" "main" {
  password = ephemeral.aws_secretsmanager_secret_version.db_creds.secret_string
}
```

## Terraform Actions (1.14+)

Imperative Day 2 operations bound to resource lifecycle. Unlike resources (declarative desired state), actions perform one-time operations like invoking a Lambda, stopping an EC2 instance, or invalidating a CloudFront distribution:

```hcl
resource "aws_lambda_function" "processor" {
  function_name = "data-processor"
  runtime       = "python3.12"
  handler       = "main.handler"
  # ...
}

action "invoke" {
  resource = aws_lambda_function.processor
  # Triggers imperative operation tied to resource lifecycle
}
```

## Resource Naming Conventions

| Cloud | Resource | Pattern |
|-------|----------|---------|
| GCP | Buckets | `{prefix}-{project_id}` (globally unique) |
| GCP | Cloud Run | `{service-name}` |
| AWS | S3 | `{project}-{env}-{purpose}` (globally unique) |
| AWS | Lambda | `{project}-{env}-{function}` |

## Related

- [Modules](./modules.md) | [Variables](./variables.md) | [Import/Moved](./import-moved.md)
