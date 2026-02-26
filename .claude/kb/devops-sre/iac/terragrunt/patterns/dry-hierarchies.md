# DRY Hierarchies Pattern

> **Purpose**: Eliminate configuration duplication through root -> env -> module inheritance
> **MCP Validated**: 2026-02-19

## When to Use

- Multiple environments share 80%+ configuration
- Want single source of truth for providers/backends
- Need to override specific values per environment
- Managing complex unit configurations
- **Consider Stacks (v0.78.0+)** as an alternative to copy-pasted `terragrunt.hcl` files

## Implementation

```text
# Configuration inheritance flow
ROOT (terragrunt.hcl)
  |-- Backend generation (GCS)
  |-- Provider generation (Google)
  |-- Common inputs (project_id, region)
  v
_ENV (optional: _env/cloud-run.hcl)
  |-- Shared module configuration
  |-- Default inputs for module type
  v
ENV (environments/dev/env.hcl)
  |-- Environment variables
  |-- Resource sizing
  v
MODULE (environments/dev/cloud-run/terragrunt.hcl)
  |-- Module source
  |-- Dependencies
  |-- Final inputs (merged)
```

```hcl
# infrastructure/terragrunt.hcl (ROOT - Level 1)
locals {
  env_config = read_terragrunt_config(
    find_in_parent_folders("env.hcl")
  )
  project_id = local.env_config.locals.project_id
  region     = local.env_config.locals.region
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

# Common inputs inherited by ALL modules
inputs = {
  project_id = local.project_id
  region     = local.region
  labels = {
    managed_by = "terragrunt"
  }
}
```

```hcl
# infrastructure/environments/_env/cloud-run.hcl (SHARED MODULE CONFIG - Level 2)
locals {
  # Default Cloud Run settings
  default_memory        = "512Mi"
  default_cpu           = "1"
  default_timeout       = "300s"
  default_concurrency   = 80
}

terraform {
  source = "${get_terragrunt_dir()}/../../modules//cloud-run"
}

# Default inputs for all Cloud Run modules
inputs = {
  timeout_seconds = local.default_timeout
  concurrency     = local.default_concurrency
}
```

```hcl
# infrastructure/environments/dev/cloud-run/terragrunt.hcl (MODULE - Level 4)
include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

include "cloud_run" {
  path           = find_in_parent_folders("_env/cloud-run.hcl")
  expose         = true
  merge_strategy = "deep"
}

dependency "pubsub" {
  config_path = "../pubsub"
}

# Module-specific inputs (merged with inherited)
inputs = {
  service_name  = "invoice-processor"
  min_instances = include.env.locals.cloud_run_min_instances
  max_instances = include.env.locals.cloud_run_max_instances
  memory        = include.env.locals.cloud_run_memory
  topic_id      = dependency.pubsub.outputs.topic_id
}
```

## Configuration

| Level | File | Provides | Merge |
|-------|------|----------|-------|
| Root | `terragrunt.hcl` | Backend, providers | Always |
| _env | `_env/*.hcl` | Module defaults | Optional |
| Env | `env.hcl` | Environment vars | expose |
| Module | `*/terragrunt.hcl` | Final config | deep |

## Merge Strategies

```hcl
include "parent" {
  path           = find_in_parent_folders()
  merge_strategy = "deep"  # or "shallow", "no_merge"
}
```

| Strategy | Behavior |
|----------|----------|
| `shallow` | Child replaces parent blocks |
| `deep` | Recursive merge, child wins conflicts |
| `no_merge` | Reference only, no inheritance |

## Example Usage

```bash
# Check effective configuration
terragrunt render-json

# See what will be applied
terragrunt run-all plan
```

## Stacks Alternative (v0.78.0+)

Instead of manually duplicating `terragrunt.hcl` files per environment, Stacks
let you define a reusable collection of units once:

```hcl
# terragrunt.stack.hcl
unit "vpc" {
  source = "./modules/vpc"
  path   = "environments/${local.env}/vpc"
}

unit "app" {
  source = "./modules/app"
  path   = "environments/${local.env}/app"
}
```

Run `terragrunt stack generate` to materialize. Stacks reduce copy-paste while
preserving the same DRY hierarchy pattern underneath.

## See Also

- [multi-environment-config.md](multi-environment-config.md)
- [environment-hierarchy.md](../concepts/environment-hierarchy.md)
- [terragrunt-blocks.md](../concepts/terragrunt-blocks.md)
