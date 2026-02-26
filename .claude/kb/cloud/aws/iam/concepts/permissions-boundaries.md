# Permissions Boundaries

> **Purpose**: Delegation guardrails that cap maximum permissions for users and roles
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A permissions boundary is a managed policy that sets the maximum permissions an identity can have. It doesn't grant permissions on its own -- it limits what identity-based policies can grant. This enables safe delegation: an admin can allow developers to create roles without risking privilege escalation.

## How It Works

The effective permissions are the **intersection** of:
- Identity-based policies (what's granted)
- Permissions boundary (what's allowed)

```
Effective Permissions = Identity Policy  INTERSECT  Permissions Boundary
```

If an identity-based policy grants `s3:*` but the boundary only allows `s3:GetObject`, the effective permission is `s3:GetObject`.

## Setting a Permissions Boundary

```bash
# Create a boundary policy
aws iam create-policy \
  --policy-name DeveloperBoundary \
  --policy-document file://boundary.json

# Attach as permissions boundary (not as regular policy)
aws iam put-role-permissions-boundary \
  --role-name DevRole \
  --permissions-boundary arn:aws:iam::123456789012:policy/DeveloperBoundary
```

### Boundary Policy Example

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowedServices",
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "dynamodb:*",
        "lambda:*",
        "logs:*",
        "sqs:*",
        "sns:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyBoundaryChanges",
      "Effect": "Deny",
      "Action": [
        "iam:DeleteRolePermissionsBoundary",
        "iam:PutRolePermissionsBoundary"
      ],
      "Resource": "*"
    }
  ]
}
```

## Delegation Pattern

Allow developers to create roles **only** with a specific boundary attached:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCreateRoleWithBoundary",
      "Effect": "Allow",
      "Action": "iam:CreateRole",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:PermissionsBoundary": "arn:aws:iam::123456789012:policy/DeveloperBoundary"
        }
      }
    },
    {
      "Sid": "AllowAttachPoliciesWithBoundary",
      "Effect": "Allow",
      "Action": [
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy"
      ],
      "Resource": "arn:aws:iam::123456789012:role/dev-*"
    },
    {
      "Sid": "PreventBoundaryRemoval",
      "Effect": "Deny",
      "Action": [
        "iam:DeleteRolePermissionsBoundary",
        "iam:PutRolePermissionsBoundary"
      ],
      "Resource": "*"
    }
  ]
}
```

## Evaluation Order

1. Explicit Deny (any policy) -> DENY
2. SCP must allow (if Organization)
3. **Permissions boundary must allow** (if set)
4. Identity-based or resource-based must allow
5. Otherwise -> implicit DENY

## Quick Reference

| Scenario | Boundary Set? | Identity Policy Grants | Result |
|----------|---------------|----------------------|--------|
| No boundary | No | `s3:*` | `s3:*` allowed |
| Boundary allows `s3:Get*` | Yes | `s3:*` | Only `s3:Get*` allowed |
| Boundary allows `s3:*` | Yes | `s3:GetObject` | Only `s3:GetObject` allowed |
| Boundary has explicit Deny | Yes | `s3:*` | Denied action is always denied |

## Common Mistakes

### Wrong
```bash
# Allowing developers to create roles without boundary requirement
# This enables privilege escalation!
aws iam attach-role-policy --role-name DevRole \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

### Correct
```bash
# Require boundary on all developer-created roles
# Plus deny boundary removal in the boundary itself
```

## Related

- [Policies](policies.md) -- policy evaluation logic
- [Cross-Account Access](../patterns/cross-account-access.md) -- SCPs as account-level boundaries
- [Least Privilege](../patterns/least-privilege.md) -- boundary as defense-in-depth
