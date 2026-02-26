# IAM Roles

> **Purpose**: Role types, trust policies, assumption mechanics, and instance profiles
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

IAM roles are the preferred identity type in AWS. Unlike users, roles have no permanent credentials. A principal assumes a role via STS to get temporary credentials. Every role has two sides: a trust policy (who can assume it) and permission policies (what it can do).

## Trust Policy

The trust policy is a resource-based policy attached to the role defining which principals can call `sts:AssumeRole`.

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "lambda.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
```

### Principal Types in Trust Policies

| Principal Type | Format | Use Case |
|----------------|--------|----------|
| AWS Account | `"AWS": "arn:aws:iam::123456789012:root"` | Cross-account (allows all roles/users in account) |
| IAM Role | `"AWS": "arn:aws:iam::123456789012:role/RoleName"` | Specific cross-account role |
| AWS Service | `"Service": "lambda.amazonaws.com"` | Service role (Lambda, ECS, EC2, etc.) |
| Federated | `"Federated": "arn:aws:iam::123:saml-provider/X"` | SAML/OIDC federation |
| Everyone | `"AWS": "*"` | Public (use only with strong conditions!) |

## Role Types

### Service Role
AWS service assumes the role to act on your behalf.

```json
{
  "Principal": { "Service": "ecs-tasks.amazonaws.com" },
  "Action": "sts:AssumeRole"
}
```

### Cross-Account Role
Allows principals in another AWS account to assume this role.

```json
{
  "Principal": { "AWS": "arn:aws:iam::111122223333:role/AdminRole" },
  "Action": "sts:AssumeRole",
  "Condition": {
    "StringEquals": { "sts:ExternalId": "unique-secret-id" }
  }
}
```

### Instance Profile
Container for an EC2 role. One instance profile per role; attached at EC2 launch.

```bash
aws iam create-instance-profile --instance-profile-name MyProfile
aws iam add-role-to-instance-profile \
  --instance-profile-name MyProfile \
  --role-name MyEC2Role
```

## Assuming a Role

```python
import boto3

sts = boto3.client("sts")
response = sts.assume_role(
    RoleArn="arn:aws:iam::123456789012:role/CrossAccountRole",
    RoleSessionName="my-session",
    DurationSeconds=3600
)
creds = response["Credentials"]
# Use creds["AccessKeyId"], creds["SecretAccessKey"], creds["SessionToken"]
```

## Session Duration

| Scenario | Default | Maximum |
|----------|---------|---------|
| Console (federation) | 1 hour | 12 hours |
| CLI/SDK AssumeRole | 1 hour | 12 hours (configurable on role) |
| AssumeRoleWithWebIdentity | 1 hour | Role max session duration |
| EC2 instance role | Auto-rotated | N/A (managed by metadata service) |

## Common Mistakes

### Wrong
```json
// Trust policy allowing entire account with no conditions
{ "Principal": { "AWS": "arn:aws:iam::123456789012:root" } }
```

### Correct
```json
// Restrict to specific role and require MFA
{
  "Principal": { "AWS": "arn:aws:iam::123456789012:role/SpecificRole" },
  "Condition": { "Bool": { "aws:MultiFactorAuthPresent": "true" } }
}
```

## Related

- [Principals and Identities](principals-identities.md) -- identity types overview
- [STS and Federation](sts-federation.md) -- temporary credentials in depth
- [Service Roles pattern](../patterns/service-roles.md) -- practical service role examples
- [Cross-Account pattern](../patterns/cross-account-access.md) -- multi-account setup
