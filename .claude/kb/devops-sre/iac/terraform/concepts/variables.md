# Variables, Locals, and Outputs

> **Purpose**: Parameterize configurations for reusability
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Variables make Terraform configurations flexible and reusable. Input variables accept values from outside, local values simplify expressions, and outputs expose values to other configurations or users.

## Input Variables

### Declaration

```hcl
# variables.tf
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "enable_apis" {
  description = "Whether to enable required APIs"
  type        = bool
  default     = true
}
```

### Variable Types

| Type | Example | Use Case |
|------|---------|----------|
| `string` | `"us-central1"` | Single values |
| `number` | `100` | Counts, sizes |
| `bool` | `true` | Feature flags |
| `list(string)` | `["a", "b"]` | Multiple values |
| `set(string)` | `toset(["a", "b"])` | Unique values |
| `map(string)` | `{key = "value"}` | Key-value pairs |
| `object({...})` | Complex structures | Nested configs |

## Setting Variable Values

```bash
# terraform.tfvars, *.auto.tfvars, or command line:
terraform apply -var="project_id=my-project" -var-file="prod.tfvars"
```

## Local Values

Simplify complex expressions:

```hcl
# locals.tf
locals {
  # Computed values
  bucket_prefix = "${var.environment}-${var.project_id}"

  # Common tags
  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = var.project_id
  }

  # Service list
  pipeline_stages = ["uploaded", "converted", "classified", "extracted"]
}

# Usage
resource "google_storage_bucket" "invoices" {
  name   = "${local.bucket_prefix}-invoices"
  labels = local.common_labels
}
```

## Outputs

```hcl
output "bucket_url" {
  description = "URL of the bucket"
  value       = google_storage_bucket.input.url
  sensitive   = false  # Set true to hide in logs
}
```

## Variable Precedence (Highest to Lowest)

1. `-var` / `-var-file` > 2. `*.auto.tfvars` > 3. `terraform.tfvars` > 4. `TF_VAR_*` env vars > 5. Defaults

## Ephemeral Variables (1.10+)

Values not persisted in state or plan files. Use for secrets and short-lived tokens:

```hcl
variable "api_token" {
  type      = string
  ephemeral = true  # never written to state or plan
}

output "token_hash" {
  value     = sha256(var.api_token)
  ephemeral = true  # ephemeral output, not stored
}
```

## Write-Only Arguments (1.11+)

Ephemeral values can flow into managed resources via write-only arguments. The value is sent to the provider API but never stored in state:

```hcl
resource "aws_db_instance" "main" {
  password = var.db_password  # write-only: sent to AWS, not in state
}
```

## Deprecated Attribute (1.15-alpha)

Mark variables and outputs as deprecated with a warning message:

```hcl
variable "old_name" {
  type       = string
  deprecated = "Use var.new_name instead"
}
```

## Related

- [Resources](./resources.md) | [Modules](./modules.md) | [Cloud Run Module](../patterns/cloud-run-module.md)
