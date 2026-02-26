# Terragrunt Knowledge Base

> **Purpose**: Terraform/OpenTofu wrapper for multi-environment orchestration, DRY configurations, dependency management, and Stacks
> **MCP Validated**: 2026-02-19
> **Version**: 0.99.x

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/terragrunt-blocks.md](concepts/terragrunt-blocks.md) | Core HCL blocks: include, dependency, inputs, locals, stack |
| [concepts/root-configuration.md](concepts/root-configuration.md) | Root terragrunt.hcl, labeled includes, provider setup |
| [concepts/environment-hierarchy.md](concepts/environment-hierarchy.md) | Folder structure for multi-env setups + Stacks alternative |
| [concepts/generate-blocks.md](concepts/generate-blocks.md) | Dynamic file generation for backends |
| [concepts/dependency-graphs.md](concepts/dependency-graphs.md) | Unit dependencies, execution order, --filter flag |
| [concepts/hooks.md](concepts/hooks.md) | before_hook, after_hook, error_hook, tflint deprecation |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/multi-environment-config.md](patterns/multi-environment-config.md) | Dev/prod with different GCP projects + Stacks |
| [patterns/dry-hierarchies.md](patterns/dry-hierarchies.md) | Root to env to module inheritance + Stacks alternative |
| [patterns/dependency-management.md](patterns/dependency-management.md) | Cross-unit output passing + --filter flag |
| [patterns/state-bucket-per-env.md](patterns/state-bucket-per-env.md) | Isolated state per environment |
| [patterns/environment-promotion.md](patterns/environment-promotion.md) | Promoting changes dev to prod |

### Specs (Machine-Readable)

| File | Purpose |
|------|---------|
| [specs/gcp-project-structure.yaml](specs/gcp-project-structure.yaml) | Standard GCP Terragrunt layout |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **unit** | One instance of an OpenTofu/Terraform module (formalized term) |
| **stack** | Reusable collection of units defined in `terragrunt.stack.hcl` (GA v0.78.0) |
| **include** | Merge parent config into child (labeled required since v0.81.0) |
| **dependency** | Define execution order between units |
| **generate** | Create files dynamically (backend, providers) |
| **inputs** | Pass variables to Terraform/OpenTofu modules |
| **run-all** | Execute across multiple units respecting deps |
| **--filter** | Graph/Git-based expressions to target unit subsets (v0.98.0+) |

---

## What's New (v0.68.x to v0.99.x)

| Feature | Version | Impact |
|---------|---------|--------|
| **Stacks (GA)** | v0.78.0 | `terragrunt.stack.hcl` defines reusable unit collections |
| **Units terminology** | v0.78.0 | A "unit" = one instance of a Terraform/OpenTofu module |
| **Bare includes deprecated** | v0.81.0 | Must use `include "label" {}`, bare `include {}` warns |
| **--filter flag** | v0.98.0 | Graph/Git-based targeting of unit subsets |
| **Internal tflint deprecated** | v0.99.0 | Use external tflint instead |
| **Runner Pools** | v0.80.0+ | Faster parallel deployments for large environments |
| **Run Summaries** | v0.80.0+ | Overview of multi-unit execution results |
| **OpenTofu Provider Cache** | v0.80.0+ | Speed boost for provider downloads |
| **SOPS race condition fix** | v0.99.2 | Synchronized per-environment SOPS decryption |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/terragrunt-blocks.md, concepts/root-configuration.md |
| **Intermediate** | patterns/multi-environment-config.md, patterns/dry-hierarchies.md |
| **Advanced** | patterns/dependency-management.md, concepts/hooks.md, concepts/dependency-graphs.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| terraform-developer | patterns/multi-environment-config.md | Setup new environment |
| infrastructure-agent | patterns/dependency-management.md | Unit orchestration |

---

## Project Context

This KB supports the GenAI Invoice Processing Pipeline infrastructure:
- Multi-environment GCP deployment (dev/prod)
- Unit dependencies: VPC -> Pub/Sub -> Cloud Run -> BigQuery
- Remote state in GCS with per-environment buckets
- DRY configuration across cloud-run, pubsub, gcs, bigquery, iam units
