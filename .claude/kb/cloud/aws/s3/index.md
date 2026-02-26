# AWS S3 Knowledge Base

> **Purpose**: Amazon Simple Storage Service -- scalable object storage with 99.999999999% durability
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/buckets-objects.md](concepts/buckets-objects.md) | Buckets, objects, keys, prefixes, naming |
| [concepts/storage-classes.md](concepts/storage-classes.md) | S3 Standard, IA, Glacier, Intelligent-Tiering |
| [concepts/security-access.md](concepts/security-access.md) | IAM policies, bucket policies, ACLs, encryption |
| [concepts/versioning-lifecycle.md](concepts/versioning-lifecycle.md) | Object versioning, lifecycle rules, transitions |
| [concepts/event-notifications.md](concepts/event-notifications.md) | S3 events, EventBridge, Lambda triggers |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/data-lake-pattern.md](patterns/data-lake-pattern.md) | S3 as data lake foundation with medallion layers |
| [patterns/static-hosting.md](patterns/static-hosting.md) | Static website hosting with CloudFront |
| [patterns/cross-region-replication.md](patterns/cross-region-replication.md) | CRR/SRR for disaster recovery and compliance |
| [patterns/performance-optimization.md](patterns/performance-optimization.md) | Multipart upload, transfer acceleration, prefixes |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Object Storage** | Flat namespace; objects stored as key-value pairs in buckets |
| **11 Nines Durability** | 99.999999999% durability across multiple AZs |
| **50 TB Max Object Size** | Single object up to 50 TB (Dec 2025); multipart upload required >5 TB |
| **Storage Classes** | 8 tiers from hot (Standard) to cold (Glacier Deep Archive) |
| **Conditional Writes** | `if-none-match` and `if-match` (ETag) on PutObject and CopyObject |
| **S3 Express One Zone** | Single-digit ms latency, RenameObject API, significant price reductions |
| **Server-Side Encryption** | SSE-S3 (default), SSE-KMS, SSE-C for data at rest |
| **Event-Driven** | Native integration with Lambda, SQS, SNS, EventBridge |
| **Data Lake Foundation** | Decouple storage from compute; query with Athena, EMR, Redshift Spectrum |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/buckets-objects.md, concepts/storage-classes.md |
| **Intermediate** | concepts/security-access.md, concepts/versioning-lifecycle.md |
| **Advanced** | patterns/data-lake-pattern.md, patterns/performance-optimization.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| lambda-builder | concepts/event-notifications.md, patterns/data-lake-pattern.md | S3-triggered Lambda functions |
| aws-lambda-architect | concepts/security-access.md | IAM policies for S3 access |
| aws-deployer | patterns/static-hosting.md | S3 + CloudFront deployments |
| infra-deployer | patterns/cross-region-replication.md | Terraform S3 infrastructure |

---

## Cross-References

| Technology | KB Path | Relationship |
|------------|---------|--------------|
| Terraform | `../../devops-sre/iac/terraform/` | Infrastructure as Code for S3 |
| Dagster | `../../data-engineering/orchestration/dagster/` | Orchestrate S3 data pipelines |
| dbt | `../../data-engineering/transformation/dbt/` | Read/write models from S3 data lake |
