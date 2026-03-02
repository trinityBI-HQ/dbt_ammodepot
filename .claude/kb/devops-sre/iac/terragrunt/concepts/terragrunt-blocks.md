# Terragrunt Blocks

> **Purpose**: Core HCL configuration blocks for terragrunt.hcl and terragrunt.stack.hcl files
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Terragrunt extends Terraform/OpenTofu with special HCL blocks for DRY configurations,
dependency management, code generation, and Stacks. Each block serves a specific purpose.
A "unit" is one instance of a Terraform/OpenTofu module (formalized in v0.78.0).

## The Pattern

```hcl
# Complete terragrunt.hcl showing all major blocks

locals {
  # Local variables scoped to this file
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_id  = local.env_vars.locals.project_id
  region      = local.env_vars.locals.region
}

include "root" {
  # Inherit from parent configuration
  path = find_in_parent_folders()
}

dependency "vpc" {
  # Declare dependency on another module
  config_path = "../vpc"

  mock_outputs = {
    network_name = "mock-vpc"
  }
}

terraform {
  # Module source and hooks
  source = "${get_terragrunt_dir()}/../../modules//cloud-run"
}

inputs = {
  # Variables passed to Terraform module
  project_id   = local.project_id
  region       = local.region
  network_name = dependency.vpc.outputs.network_name
}
```

## Quick Reference

| Block | Purpose | File | Required |
|-------|---------|------|----------|
| `locals` | Define local variables | `terragrunt.hcl` | No |
| `include` | Inherit parent config (label required) | `terragrunt.hcl` | Usually |
| `dependency` | Unit execution order | `terragrunt.hcl` | For deps |
| `terraform` | Source and hooks | `terragrunt.hcl` | Yes |
| `inputs` | Pass vars to module | `terragrunt.hcl` | Usually |
| `generate` | Create dynamic files | `terragrunt.hcl` | Optional |
| `remote_state` | Auto-manage state | `terragrunt.hcl` | Optional |
| `unit` | Define a stack unit | `terragrunt.stack.hcl` | In stacks |

## Block Details

### locals

```hcl
locals {
  # Read environment config from parent
  env_config = read_terragrunt_config(
    find_in_parent_folders("env.hcl")
  )

  # Extract specific values
  project_id = local.env_config.locals.project_id
  env        = local.env_config.locals.environment

  # Computed values
  resource_prefix = "${local.env}-invoice"
}
```

### include

```hcl
# Simple include
include "root" {
  path = find_in_parent_folders()
}

# Include with expose for accessing parent locals
include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

# Use exposed values
inputs = {
  project_id = include.env.locals.project_id
}
```

## Stack Blocks (v0.78.0+, GA)

```hcl
# terragrunt.stack.hcl — defines reusable collection of units
unit "vpc" {
  source = "../../modules/vpc"
  path   = "vpc"
}

unit "app" {
  source = "../../modules/app"
  path   = "app"
}
```

Run `terragrunt stack generate` to materialize units into individual `terragrunt.hcl` files.

## Common Mistakes

### Wrong: bare include (deprecated v0.81.0, breaks v2.0)

```hcl
include { path = find_in_parent_folders() }  # No label = deprecated!
```

### Correct: labeled include with expose

```hcl
include "root" {
  path   = find_in_parent_folders()
  expose = true
}
inputs = { project_id = include.root.locals.project_id }
```

## Related

- [root-configuration.md](root-configuration.md)
- [generate-blocks.md](generate-blocks.md)
- [dry-hierarchies.md](../patterns/dry-hierarchies.md)