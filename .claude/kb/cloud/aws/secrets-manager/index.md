# AWS Secrets Manager Knowledge Base

> **Purpose**: Secure storage, rotation, and management of secrets (credentials, API keys, tokens) with KMS encryption and automated Lambda-based rotation
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/secrets-overview.md](concepts/secrets-overview.md) | Secret structure, types, and lifecycle |
| [concepts/versioning.md](concepts/versioning.md) | Version stages (AWSCURRENT, AWSPREVIOUS, AWSPENDING) |
| [concepts/rotation.md](concepts/rotation.md) | Automatic rotation strategies and schedules |
| [concepts/encryption-kms.md](concepts/encryption-kms.md) | KMS encryption, CMKs, and key policies |
| [concepts/resource-policies.md](concepts/resource-policies.md) | IAM and resource-based access control |
| [concepts/replication.md](concepts/replication.md) | Multi-region secret replication |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/boto3-integration.md](patterns/boto3-integration.md) | Python SDK create, retrieve, update, delete |
| [patterns/lambda-rotation.md](patterns/lambda-rotation.md) | Lambda-based rotation function setup |
| [patterns/terraform-setup.md](patterns/terraform-setup.md) | Terraform module for secrets with rotation |
| [patterns/cross-account-access.md](patterns/cross-account-access.md) | Cross-account secret sharing patterns |
| [patterns/caching-pattern.md](patterns/caching-pattern.md) | Client-side caching for performance |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Secret** | Encrypted credential (string or binary) with metadata, versions, and rotation config |
| **Version Stage** | Labels (AWSCURRENT, AWSPREVIOUS, AWSPENDING) tracking secret lifecycle |
| **Rotation** | Automatic credential refresh via Lambda or managed rotation |
| **Resource Policy** | JSON policy attached to a secret for cross-account or fine-grained access |
| **Replica** | Read-only copy of a secret in another AWS Region |
| **Managed External Secrets** | Automatic rotation for third-party SaaS without custom Lambda |

---

## What's New (2025-2026)

| Feature | Date | Impact |
|---------|------|--------|
| Managed External Secrets | Nov 2025 | Auto-rotate Salesforce, BigID, Snowflake credentials without custom Lambda |
| Improved secret sorting | Dec 2025 | Sort by name, last changed, last accessed, creation date in console |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/secrets-overview.md, concepts/versioning.md |
| **Intermediate** | patterns/boto3-integration.md, patterns/caching-pattern.md |
| **Advanced** | patterns/lambda-rotation.md, patterns/cross-account-access.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| aws-lambda-architect | patterns/lambda-rotation.md | Rotation Lambda design |
| lambda-builder | patterns/boto3-integration.md | Secret retrieval in handlers |
| infra-deployer | patterns/terraform-setup.md | IaC for secrets |
