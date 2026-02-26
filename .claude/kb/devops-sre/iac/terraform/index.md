# Terraform Knowledge Base

> **Purpose**: Infrastructure as Code reference for multi-cloud architecture (GCP + AWS)
> **Version**: 1.14.x (stable)
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/resources.md](concepts/resources.md) | Resources, data sources, meta-arguments |
| [concepts/modules.md](concepts/modules.md) | Module structure, inputs, outputs |
| [concepts/providers.md](concepts/providers.md) | GCP + AWS provider configuration |
| [concepts/state.md](concepts/state.md) | State management and remote backends |
| [concepts/variables.md](concepts/variables.md) | Variables, locals, and outputs |
| [concepts/workspaces.md](concepts/workspaces.md) | Environment isolation with workspaces |
| [concepts/testing.md](concepts/testing.md) | Native test framework (`terraform test`) |
| [concepts/import-moved.md](concepts/import-moved.md) | Import, moved, and removed blocks |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| **GCP** | |
| [patterns/cloud-run-module.md](patterns/cloud-run-module.md) | Cloud Run service with Pub/Sub trigger |
| [patterns/pubsub-module.md](patterns/pubsub-module.md) | Topics, subscriptions, dead-letter queues |
| [patterns/gcs-module.md](patterns/gcs-module.md) | Buckets, lifecycle rules, notifications |
| [patterns/bigquery-module.md](patterns/bigquery-module.md) | Datasets, tables, schemas |
| [patterns/iam-module.md](patterns/iam-module.md) | GCP service accounts and IAM bindings |
| [patterns/remote-state.md](patterns/remote-state.md) | GCS backend for state management |
| **AWS** | |
| [patterns/aws-s3-module.md](patterns/aws-s3-module.md) | S3 bucket with encryption, versioning, lifecycle |
| [patterns/aws-lambda-module.md](patterns/aws-lambda-module.md) | Lambda function with IAM role and event sources |
| [patterns/aws-iam-module.md](patterns/aws-iam-module.md) | AWS IAM roles, policies, OIDC federation |
| **Multi-Cloud** | |
| [patterns/multi-cloud-structure.md](patterns/multi-cloud-structure.md) | Project layout for multi-cloud deployments |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables for commands and configs

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Declarative IaC** | Define desired state, Terraform reconciles |
| **Modules** | Reusable, composable infrastructure packages |
| **State** | Source of truth for managed resources |
| **Providers** | Plugins for cloud platform APIs (GCP, AWS, Azure) |
| **Testing** | Native test framework with assertions (1.6+) |
| **Import** | Bring existing resources under management (1.5+) |
| **Ephemeral Values** | Secrets/tokens not persisted in state or plan (1.10+) |
| **Actions** | Imperative Day 2 operations bound to resource lifecycle (1.14+) |
| **Stacks** | Multi-workspace deployment at scale (GA Sep 2025) |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/resources.md, concepts/variables.md |
| **Intermediate** | concepts/modules.md, patterns/remote-state.md |
| **Advanced** | concepts/testing.md, concepts/import-moved.md, patterns/multi-cloud-structure.md |

---

## Cloud Provider Coverage

| Provider | Patterns | Key Services |
|----------|----------|--------------|
| **GCP** | 6 patterns | Cloud Run, Pub/Sub, GCS, BigQuery, IAM |
| **AWS** | 3 patterns | S3, Lambda, IAM |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| infra-deployer | patterns/*.md | Provision GCP resources |
| aws-lambda-architect | patterns/aws-*.md | Provision AWS resources |
| ci-cd-specialist | patterns/multi-cloud-structure.md | Multi-cloud deployments |

---

## Version History (1.10 - 1.14)

| Version | Release | Key Features |
|---------|---------|--------------|
| **1.10** | 2024 | Ephemeral values, ephemeral resources, parallel tests |
| **1.11** | Mar 2025 | Write-only arguments, test framework improvements |
| **1.13** | Aug 2025 | `terraform stacks` CLI, `terraform rpcapi` GA, better errors |
| **1.14** | Sep 2025 | Terraform Actions (Day 2 ops), resource lifecycle actions |
| **1.15-alpha** | Feb 2026 | `deprecated` attribute, Windows ARM64, `aws login` for S3 backend |

## Ecosystem Updates

| Feature | Status | Description |
|---------|--------|-------------|
| **Terraform Stacks** | GA (Sep 2025) | Deploy across many workspaces with single stack definition |
| **Terraform MCP Server** | Released (HashiConf 2025) | Connect HCP Terraform to AI assistants via MCP |
| **OpenTofu 1.11** | Released | Ephemeral resources, write-only attrs, `enabled` meta-argument |

## External Resources

- [Terraform Docs](https://developer.hashicorp.com/terraform/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Registry](https://registry.terraform.io/)
- [Terraform Stacks Docs](https://developer.hashicorp.com/terraform/language/stacks)
- [Terraform Actions Docs](https://developer.hashicorp.com/terraform/language/resources/actions)
