# State

> **Purpose**: Source of truth for managed infrastructure
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Terraform state is a JSON file that maps configuration to real-world resources. It tracks resource IDs, dependencies, and metadata. Without state, Terraform cannot know which resources it manages.

## State Purpose

| Function | Description |
|----------|-------------|
| Resource mapping | Links config to actual resources |
| Metadata storage | Tracks dependencies and attributes |
| Performance | Caches resource data |
| Collaboration | Enables team workflows |

## Local vs Remote State

### Local State (Development Only)

```hcl
# Default - state stored in terraform.tfstate
# DO NOT commit to version control
```

### Remote State (Production)

```hcl
terraform {
  backend "gcs" {
    bucket = "tf-state-${var.project_id}"
    prefix = "terraform/state"
  }
}
```

## GCS Backend Configuration

### Backend Setup

```hcl
# backend.tf
terraform {
  backend "gcs" {
    bucket = "tf-state-myproject"
    prefix = "env/prod"
  }
}
```

### Create State Bucket

```hcl
# bootstrap/main.tf - Run once manually
resource "google_storage_bucket" "terraform_state" {
  name          = "tf-state-${var.project_id}"
  location      = "US"
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }
}
```

## State Locking

GCS backend provides automatic state locking to prevent concurrent modifications:

```hcl
terraform {
  backend "gcs" {
    bucket = "tf-state-myproject"
    prefix = "env/prod"
    # Locking is automatic via GCS
  }
}
```

## State Commands

| Command | Purpose |
|---------|---------|
| `terraform state list` | List all resources |
| `terraform state show <resource>` | Show resource details |
| `terraform state mv` | Rename/move resource |
| `terraform state rm` | Remove from state (not infra) |
| `terraform state pull` | Download remote state |
| `terraform state push` | Upload state (dangerous) |

## Best Practices

Remote backend with locking, bucket versioning, encryption at rest, <100 resources per state, separate environments for blast radius.
## Reading Remote State

Access outputs from other configurations:

```hcl
data "terraform_remote_state" "network" {
  backend = "gcs"
  config = {
    bucket = "tf-state-myproject"
    prefix = "network/prod"
  }
}

# Use outputs
resource "google_cloud_run_service" "api" {
  # ...
  vpc_connector = data.terraform_remote_state.network.outputs.vpc_connector_id
}
```

## Ephemeral Values and State (1.10+)

Ephemeral values are **never written** to state or plan files, solving the long-standing problem of secrets leaking into state:

| Type | Stored in State? | Example |
|------|-----------------|---------|
| Regular variable | Yes | `var.region` |
| Sensitive variable | Yes (marked sensitive) | `var.db_password` |
| **Ephemeral variable** | **No** | `var.api_token` with `ephemeral = true` |
| **Ephemeral resource** | **No** | `ephemeral "aws_secretsmanager_secret_version"` |

Write-only arguments (1.11+) allow ephemeral values to flow into managed resources without the value persisting in state. The provider receives the value but Terraform does not store it.

## Common Mistakes

| Wrong | Correct |
|-------|---------|
| State in git | Use GCS/S3 backend, add `*.tfstate` to `.gitignore` |
| Secrets as regular vars | Use ephemeral variables (1.10+) or `sensitive = true` |

## Related

- [Providers](./providers.md) | [Remote State](../patterns/remote-state.md) | [Workspaces](./workspaces.md)
