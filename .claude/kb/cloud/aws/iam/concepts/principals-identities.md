# Principals and Identities

> **Purpose**: IAM identity types -- users, groups, roles, root, and federated identities
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

An IAM principal is any entity that can make requests to AWS. AWS supports several identity types: the root user, IAM users, IAM groups, IAM roles, and federated identities. Modern best practice favors roles and federation over long-lived IAM user credentials.

## Identity Types

### Root User

- Created when AWS account is first set up
- Has unrestricted access to all resources
- **Never use for daily tasks** -- secure with MFA, lock away credentials
- Required only for: changing account settings, closing account, restoring permissions

### IAM Users

- Represent a person or application with long-lived credentials
- Have access keys (programmatic) and/or console password
- **Modern guidance**: use Identity Center instead for human users
- Still valid for: service accounts in legacy systems, CI/CD with OIDC unavailable

```python
import boto3

# Create IAM user (prefer roles/federation instead)
iam = boto3.client("iam")
iam.create_user(UserName="ci-deployer")
iam.create_access_key(UserName="ci-deployer")
```

### IAM Groups

- Collections of IAM users for bulk permission management
- A user can belong to up to 10 groups
- Groups cannot be nested; groups cannot assume roles
- Attach policies to groups, not individual users

### IAM Roles

- Identity with no permanent credentials -- assumed via STS
- Trust policy defines who/what can assume the role
- Preferred over IAM users for almost all use cases
- Types: service role, cross-account role, federated role, service-linked role

### Service-Linked Roles

- Pre-defined by an AWS service (e.g., `AWSServiceRoleForECS`)
- Permissions managed by the service; you cannot modify the policy
- Created automatically or via `create-service-linked-role`

## Quick Reference

| Identity | Credentials | Best For | Avoid When |
|----------|-------------|----------|------------|
| Root | Email + password | Account-level tasks only | Everything else |
| IAM User | Access keys / password | Legacy service accounts | Human access (use SSO) |
| IAM Group | N/A (container) | Organizing user permissions | Nesting or role assumption |
| IAM Role | Temporary (STS) | Services, cross-account, federation | N/A -- preferred default |

## Common Mistakes

### Wrong

```json
// Sharing root credentials or using root for CI/CD
// Creating IAM users per developer with long-lived keys
{
  "UserName": "dev-sarah",
  "AccessKey": "AKIA..."  // Long-lived, no rotation
}
```

### Correct

```json
// Use Identity Center for human access
// Use roles for services and CI/CD (e.g., GitHub OIDC)
{
  "RoleName": "github-ci-deploy",
  "AssumeRolePolicyDocument": {
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" },
      "Action": "sts:AssumeRoleWithWebIdentity"
    }]
  }
}
```

## IAM Identity Center Multi-Region Replication (Feb 2026 GA)

Identity Center now supports multi-region replication:

- Replicate identities and permission sets across AWS regions
- Improves resilience for global organizations
- Supports customer-managed KMS keys for encryption (Sep 2025)
- Extended session management for Microsoft AD directories (15 min to 90 days, Apr 2025)

## Related

- [Policies](policies.md) -- attaching permissions to identities
- [Roles](roles.md) -- deep dive into role assumption
- [STS and Federation](sts-federation.md) -- temporary credentials and SSO
