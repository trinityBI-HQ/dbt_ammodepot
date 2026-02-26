# AWS IAM Knowledge Base

> **Purpose**: Identity and Access Management -- control who can access what in AWS
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/principals-identities.md](concepts/principals-identities.md) | Users, groups, roles, root account, Identity Center |
| [concepts/policies.md](concepts/policies.md) | Policy types, structure, JSON syntax, evaluation logic |
| [concepts/roles.md](concepts/roles.md) | Assume role, trust policies, service roles, instance profiles |
| [concepts/permissions-boundaries.md](concepts/permissions-boundaries.md) | Delegation guardrails, maximum permission limits |
| [concepts/conditions.md](concepts/conditions.md) | Condition keys, operators, context-aware access control |
| [concepts/sts-federation.md](concepts/sts-federation.md) | STS, temporary credentials, SAML, OIDC, Identity Center |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/least-privilege.md](patterns/least-privilege.md) | Least privilege strategies, Access Analyzer, policy refinement |
| [patterns/cross-account-access.md](patterns/cross-account-access.md) | Cross-account role assumption, Organizations, SCPs |
| [patterns/service-roles.md](patterns/service-roles.md) | Lambda, ECS, EC2 service roles with trust policies |
| [patterns/terraform-iam.md](patterns/terraform-iam.md) | Terraform IAM modules, policy-as-code, automation |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Principal** | Entity that can make requests: user, role, service, federated identity |
| **Policy** | JSON document defining permissions (Effect + Action + Resource + Condition) |
| **Role** | Identity with trust policy; assumed by principals for temporary credentials |
| **Trust Policy** | Resource-based policy on a role that defines who can assume it |
| **Permissions Boundary** | Managed policy that sets maximum permissions for an identity |
| **SCP** | Service Control Policy in Organizations; guardrails across accounts (now supports full IAM policy language) |
| **Policy Autopilot** | Open-source MCP server for code-to-policy least-privilege generation |
| **Identity Center Multi-Region** | GA multi-region replication for identities and permission sets |

---

## What's New (2025-2026)

| Feature | Date | Impact |
|---------|------|--------|
| SCPs support full IAM policy language | Sep 2025 | Conditions, individual resource ARNs, NotAction with Allow, wildcards |
| IAM Policy Autopilot (open-source MCP server) | Nov 2025 | Analyzes code and generates least-privilege IAM policies automatically |
| IAM Identity Center multi-region replication GA | Feb 2026 | Replicate identities and permission sets across regions |
| Customer-managed KMS keys for Identity Center | Sep 2025 | Encrypt Identity Center data with your own keys |
| Extended session management for Microsoft AD | Apr 2025 | Session duration range extended to 15 min - 90 days |
| TIP SDK plugin for Java 2.0 and JavaScript v3 | Apr 2025 | Trusted identity propagation for workforce identities |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/principals-identities.md, concepts/policies.md |
| **Intermediate** | concepts/roles.md, concepts/conditions.md, patterns/least-privilege.md |
| **Advanced** | concepts/permissions-boundaries.md, patterns/cross-account-access.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| aws-lambda-architect | concepts/roles.md, patterns/service-roles.md | Least-privilege Lambda execution roles |
| lambda-builder | patterns/service-roles.md | S3/DynamoDB permissions for Lambda |
| aws-deployer | patterns/terraform-iam.md | Deploy IAM resources via SAM/Terraform |
| infra-deployer | patterns/terraform-iam.md, patterns/cross-account-access.md | Multi-env IAM infrastructure |

---

## Cross-References

| Technology | KB Path | Relationship |
|------------|---------|--------------|
| S3 | `../s3/` | Bucket policies, S3 access control |
| Lambda | Agent: lambda-builder | Execution roles, resource policies |
| Terraform | `../../../devops-sre/iac/terraform/` | IAM policy-as-code, modules |
| Glue | `../glue/` | Glue service roles, Data Catalog access |
