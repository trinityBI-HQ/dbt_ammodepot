# Terragrunt Quick Reference (v0.99.x)

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Core Blocks

| Block | Purpose | Example |
|-------|---------|---------|
| `include` | Inherit parent config (label required) | `include "root" { path = find_in_parent_folders() }` |
| `dependency` | Define unit order | `dependency "vpc" { config_path = "../vpc" }` |
| `inputs` | Pass vars to Terraform/OpenTofu | `inputs = { project_id = local.project_id }` |
| `locals` | Define local variables | `locals { env = "dev" }` |
| `generate` | Create dynamic files | `generate "backend" { ... }` |
| `remote_state` | Configure state backend | `remote_state { backend = "gcs" ... }` |
| `terraform` | Module source + hooks | `terraform { source = "../modules//vpc" }` |
| `unit` | Stack unit definition | In `terragrunt.stack.hcl` only |

## Key Commands

| Command | Action |
|---------|--------|
| `terragrunt run-all plan` | Plan all units (respects deps) |
| `terragrunt run-all apply` | Apply in dependency order |
| `terragrunt run-all apply --filter "path:vpc/*"` | Apply only matching units |
| `terragrunt run-all apply --filter "git:main"` | Apply only Git-changed units |
| `terragrunt stack generate` | Materialize stack units from `terragrunt.stack.hcl` |
| `terragrunt graph-dependencies` | Visualize unit graph |

## --filter Expressions (v0.98.0+)

| Expression | Targets |
|------------|---------|
| `--filter "path:modules/vpc/*"` | Units matching path glob |
| `--filter "tag:team=platform"` | Units with specific tag |
| `--filter "git:main"` | Units changed vs main branch |
| `--filter "dep:modules/vpc"` | Units depending on vpc |

## Include Merge Strategies

| Strategy | Behavior | Use When |
|----------|----------|----------|
| `shallow` | Child overrides parent | Simple inheritance |
| `deep` | Recursive merge | Complex nested configs |
| `no_merge` | No merging | Reference only |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Auto-create state bucket | `remote_state` block |
| Manual bucket management | `generate` block |
| Share vars across envs | Root `locals` + include |
| Unit-to-unit data | `dependency` + outputs |
| Reusable infra collections | Stacks (`terragrunt.stack.hcl`) |
| Target subset of units | `--filter` flag |

## Deprecations & Breaking Changes

| What | Version | Migration |
|------|---------|-----------|
| Bare includes (`include { }`) | Warns v0.81.0, breaks v2.0 | Add label: `include "root" { }` |
| Internal tflint | Deprecated v0.99.0 | Use external tflint binary |

## Common Pitfalls

| Do Not | Do Instead |
|--------|------------|
| Use bare `include { path = ... }` | Use labeled `include "root" { path = ... }` |
| Use both `remote_state` and `generate` for backend | Pick one approach |
| Access parent locals directly | Use `expose = true` in include |
| Mix state in one bucket | Use `path_relative_to_include()` for keys |

## Related Documentation

| Topic | Path |
|-------|------|
| Block Details | `concepts/terragrunt-blocks.md` |
| Root Setup | `concepts/root-configuration.md` |
| Full Index | `index.md` |
