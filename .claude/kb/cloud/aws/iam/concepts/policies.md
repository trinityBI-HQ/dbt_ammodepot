# IAM Policies

> **Purpose**: Policy types, JSON structure, evaluation logic, and management
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

IAM policies are JSON documents that define permissions. They specify which actions are allowed or denied on which resources under which conditions. Understanding policy types and evaluation logic is essential for securing AWS environments.

## Policy Structure

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3ReadAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

## Statement Elements

| Element | Required | Description |
|---------|----------|-------------|
| `Effect` | Yes | `Allow` or `Deny` |
| `Action` | Yes* | API actions (e.g., `s3:GetObject`). Use `NotAction` to invert |
| `Resource` | Yes* | ARNs of target resources. Use `NotResource` to invert |
| `Condition` | No | Context-based restrictions (IP, time, tags, MFA) |
| `Principal` | Resource-based only | Who the policy applies to |
| `Sid` | No | Human-readable statement identifier |

*Required in identity-based; `Principal` replaces in resource-based.

## Policy Types

| Type | Where Attached | Managed By | Key Use |
|------|----------------|------------|---------|
| **AWS managed** | User/Group/Role | AWS | Common job functions (`ReadOnlyAccess`) |
| **Customer managed** | User/Group/Role | You | Organization-specific permissions |
| **Inline** | Embedded in identity | You | Strict 1:1 relationship (avoid when possible) |
| **Resource-based** | Resource (S3, SQS, Lambda) | You | Cross-account access without role assumption |
| **SCP** | Organization OU/Account | Org admin | Account-wide guardrails (full policy language since Sep 2025) |
| **Permissions boundary** | User/Role | Admin | Delegation cap on max permissions |

## Evaluation Logic

```
Request arrives
  |
  v
Explicit Deny in any policy? --> DENY (final)
  |
  No
  v
SCP allows? (if in Organization) --> No --> DENY
  |
  Yes
  v
Permissions boundary allows? (if set) --> No --> DENY
  |
  Yes
  v
Resource-based policy allows? --> Yes --> ALLOW (even without identity-based)
  |
  No
  v
Identity-based policy allows? --> Yes --> ALLOW
  |
  No
  v
DENY (implicit)
```

**Key rule**: Explicit Deny always wins. Everything else follows the chain above.

## Quick Reference

| Action | Effect |
|--------|--------|
| `s3:*` | All S3 actions (overly broad) |
| `s3:GetObject` | Read a single object |
| `s3:PutObject` | Write a single object |
| `"Resource": "*"` | All resources (avoid in production) |
| `"Resource": "arn:aws:s3:::bucket/prefix/*"` | Scoped to prefix |

## Common Mistakes

### Wrong

```json
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

### Correct

```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:ListBucket"],
  "Resource": [
    "arn:aws:s3:::my-app-data",
    "arn:aws:s3:::my-app-data/public/*"
  ]
}
```

## SCP Full Policy Language Support (Sep 2025)

SCPs now support the complete IAM policy language: conditions, individual resource ARNs, NotAction with Allow, wildcards in Action strings, and NotResource. This enables precise organization-wide guardrails:

```json
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "arn:aws:s3:::company-*",
  "Condition": { "StringEquals": { "aws:RequestedRegion": ["us-east-1", "us-west-2"] } }
}
```

## Related

- [Conditions](conditions.md) -- condition keys and operators
- [Permissions Boundaries](permissions-boundaries.md) -- capping permissions
- [Least Privilege pattern](../patterns/least-privilege.md) -- practical enforcement
