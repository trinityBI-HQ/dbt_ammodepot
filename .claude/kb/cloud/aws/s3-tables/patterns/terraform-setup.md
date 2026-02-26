# Terraform Setup for S3 Tables

> **Purpose**: Infrastructure as Code for S3 Tables using Terraform AWS provider
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Terraform provides launch-day support for S3 Tables via the AWS provider (v5.80+). Resources include `aws_s3tables_table_bucket`, `aws_s3tables_namespace`, `aws_s3tables_table`, and associated policy/maintenance resources.

## Resources Overview

| Resource | Purpose |
|----------|---------|
| `aws_s3tables_table_bucket` | Create table bucket |
| `aws_s3tables_table_bucket_policy` | Attach bucket-level policy |
| `aws_s3tables_namespace` | Create namespace |
| `aws_s3tables_table` | Create Iceberg table |
| `aws_s3tables_table_policy` | Attach table-level policy |

## Basic Setup

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Table Bucket
resource "aws_s3tables_table_bucket" "analytics" {
  name = "analytics-${var.environment}"
}

# Namespaces
resource "aws_s3tables_namespace" "bronze" {
  namespace        = ["bronze"]
  table_bucket_arn = aws_s3tables_table_bucket.analytics.arn
}

resource "aws_s3tables_namespace" "silver" {
  namespace        = ["silver"]
  table_bucket_arn = aws_s3tables_table_bucket.analytics.arn
}

resource "aws_s3tables_namespace" "gold" {
  namespace        = ["gold"]
  table_bucket_arn = aws_s3tables_table_bucket.analytics.arn
}

# Table
resource "aws_s3tables_table" "orders" {
  name             = "orders"
  namespace        = aws_s3tables_namespace.bronze.namespace[0]
  table_bucket_arn = aws_s3tables_table_bucket.analytics.arn
  format           = "ICEBERG"
}
```

## Table Bucket Policy

```hcl
data "aws_iam_policy_document" "analytics_bucket" {
  statement {
    sid     = "AllowAnalyticsTeam"
    actions = ["s3tables:*"]

    principals {
      type        = "AWS"
      identifiers = [var.analytics_role_arn]
    }

    resources = [
      aws_s3tables_table_bucket.analytics.arn,
      "${aws_s3tables_table_bucket.analytics.arn}/*",
    ]
  }
}

resource "aws_s3tables_table_bucket_policy" "analytics" {
  resource_policy  = data.aws_iam_policy_document.analytics_bucket.json
  table_bucket_arn = aws_s3tables_table_bucket.analytics.arn
}
```

## Table-Level Policy (Cross-Account)

```hcl
data "aws_iam_policy_document" "orders_table" {
  statement {
    sid     = "CrossAccountRead"
    actions = [
      "s3tables:GetTable",
      "s3tables:GetTableMetadataLocation",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::999888777666:role/DataAnalyst"]
    }

    resources = [aws_s3tables_table.orders.arn]
  }
}

resource "aws_s3tables_table_policy" "orders" {
  resource_policy  = data.aws_iam_policy_document.orders_table.json
  name             = aws_s3tables_table.orders.name
  namespace        = aws_s3tables_namespace.bronze.namespace[0]
  table_bucket_arn = aws_s3tables_table_bucket.analytics.arn
}
```

## Module Pattern

```hcl
# modules/s3-tables-lakehouse/main.tf
variable "name" { type = string }
variable "environment" { type = string }
variable "namespaces" {
  type    = list(string)
  default = ["bronze", "silver", "gold"]
}

resource "aws_s3tables_table_bucket" "this" {
  name = "${var.name}-${var.environment}"
}

resource "aws_s3tables_namespace" "layers" {
  for_each         = toset(var.namespaces)
  namespace        = [each.value]
  table_bucket_arn = aws_s3tables_table_bucket.this.arn
}

output "table_bucket_arn" {
  value = aws_s3tables_table_bucket.this.arn
}

output "namespace_arns" {
  value = { for k, v in aws_s3tables_namespace.layers : k => v.namespace }
}
```

Usage:

```hcl
module "lakehouse" {
  source      = "./modules/s3-tables-lakehouse"
  name        = "analytics"
  environment = "prod"
  namespaces  = ["bronze", "silver", "gold", "staging"]
}
```

## Related

- [../concepts/table-buckets-namespaces](../concepts/table-buckets-namespaces.md)
- [../concepts/security-access](../concepts/security-access.md)
- [Terraform KB](../../../../devops-sre/iac/terraform/)
