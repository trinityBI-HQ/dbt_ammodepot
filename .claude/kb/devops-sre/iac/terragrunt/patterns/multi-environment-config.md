# Multi-Environment Configuration Pattern

> **Purpose**: Manage dev/prod environments with different GCP projects using shared modules
> **MCP Validated**: 2026-02-19

## When to Use

- Deploying same infrastructure to multiple environments
- Using different GCP projects per environment
- Need environment-specific resource sizing
- Want isolated state per environment

## Implementation

```hcl
# infrastructure/terragrunt.hcl (ROOT)
locals {
  env_config = read_terragrunt_config(
    find_in_parent_folders("env.hcl")
  )
  project_id = local.env_config.locals.project_id
  region     = local.env_config.locals.region
  env        = local.env_config.locals.environment
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "gcs" {
    bucket = "${local.project_id}-tfstate"
    prefix = "${path_relative_to_include()}"
  }
}
EOF
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "google" {
  project = "${local.project_id}"
  region  = "${local.region}"
}
EOF
}

inputs = {
  project_id = local.project_id
  region     = local.region
  env        = local.env
}
```

```hcl
# infrastructure/environments/dev/env.hcl
locals {
  environment = "dev"
  project_id  = "invoice-processing-dev"
  region      = "us-central1"

  # Dev: minimal resources
  cloud_run_min_instances = 0
  cloud_run_max_instances = 2
  cloud_run_memory        = "512Mi"
  cloud_run_cpu           = "1"

  # Dev: relaxed quotas
  pubsub_message_retention = "600s"
  bigquery_partition_expiration_days = 30
}
```

```hcl
# infrastructure/environments/prod/env.hcl
locals {
  environment = "prod"
  project_id  = "invoice-processing-prod"
  region      = "us-central1"

  # Prod: scaled resources
  cloud_run_min_instances = 2
  cloud_run_max_instances = 100
  cloud_run_memory        = "2Gi"
  cloud_run_cpu           = "2"

  # Prod: durable storage
  pubsub_message_retention = "604800s"  # 7 days
  bigquery_partition_expiration_days = null  # Never expire
}
```

```hcl
# infrastructure/environments/dev/cloud-run/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

dependency "pubsub" {
  config_path = "../pubsub"
  mock_outputs = {
    topic_id = "mock-topic"
  }
}

terraform {
  source = "${get_terragrunt_dir()}/../../../modules//cloud-run"
}

inputs = {
  service_name  = "invoice-processor"
  min_instances = include.env.locals.cloud_run_min_instances
  max_instances = include.env.locals.cloud_run_max_instances
  memory        = include.env.locals.cloud_run_memory
  cpu           = include.env.locals.cloud_run_cpu
  topic_id      = dependency.pubsub.outputs.topic_id
}
```

## Configuration

| Setting | Dev | Prod | Description |
|---------|-----|------|-------------|
| `project_id` | `*-dev` | `*-prod` | GCP project isolation |
| `min_instances` | `0` | `2+` | Cold start vs availability |
| `max_instances` | `2` | `100` | Cost vs scale |
| `state_bucket` | `*-dev-tfstate` | `*-prod-tfstate` | State isolation |

## Example Usage

```bash
# Apply only dev environment
cd infrastructure/environments/dev
terragrunt run-all apply

# Apply only prod environment
cd infrastructure/environments/prod
terragrunt run-all apply

# Target specific units with --filter (v0.98.0+)
terragrunt run-all plan --filter "path:environments/dev/*"
terragrunt run-all apply --filter "git:main"  # Only changed units
```

## Stacks Alternative (v0.78.0+)

Define environments as a stack instead of duplicating `terragrunt.hcl` files:

```hcl
# terragrunt.stack.hcl
unit "dev_vpc" {
  source = "./modules/vpc"
  path   = "environments/dev/vpc"
}
unit "prod_vpc" {
  source = "./modules/vpc"
  path   = "environments/prod/vpc"
}
```

Run `terragrunt stack generate` to create all unit files.

## See Also

- [dry-hierarchies.md](dry-hierarchies.md)
- [state-bucket-per-env.md](state-bucket-per-env.md)
- [environment-hierarchy.md](../concepts/environment-hierarchy.md)
