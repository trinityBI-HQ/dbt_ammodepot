# Cross-Account Access Pattern

> **Purpose**: Secure multi-account access using role assumption and Organizations
> **MCP Validated**: 2026-02-19

## When to Use

- Multi-account AWS environments (dev/staging/prod)
- Centralized CI/CD deploying to multiple accounts
- Shared services account accessing application accounts
- Third-party vendor access with ExternalId

## Architecture

```
Account A (Source)              Account B (Target)
+-----------------+            +------------------+
| IAM Role/User   | ------>   | Cross-Account    |
| (sts:AssumeRole)|  assume   | Role             |
+-----------------+            | Trust: Account A |
                               | Perms: s3:Get*   |
                               +------------------+
```

## Implementation

### Step 1: Target Account -- Create Role with Trust Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111111111111:role/CI-DeployRole"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:PrincipalOrgID": "o-abc123def4"
        }
      }
    }
  ]
}
```

### Step 2: Target Account -- Attach Permission Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::deploy-artifacts-prod",
        "arn:aws:s3:::deploy-artifacts-prod/*"
      ]
    }
  ]
}
```

### Step 3: Source Account -- Allow Assumption

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::222222222222:role/DeployTargetRole"
    }
  ]
}
```

### Step 4: Assume from Code

```python
import boto3

sts = boto3.client("sts")
assumed = sts.assume_role(
    RoleArn="arn:aws:iam::222222222222:role/DeployTargetRole",
    RoleSessionName="ci-deploy-pipeline"
)

# Create client using temporary credentials
s3 = boto3.client(
    "s3",
    aws_access_key_id=assumed["Credentials"]["AccessKeyId"],
    aws_secret_access_key=assumed["Credentials"]["SecretAccessKey"],
    aws_session_token=assumed["Credentials"]["SessionToken"]
)
```

## Third-Party Access with ExternalId

When granting access to vendors, use ExternalId to prevent confused deputy:

```json
{
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::999888777666:root" },
  "Action": "sts:AssumeRole",
  "Condition": {
    "StringEquals": {
      "sts:ExternalId": "vendor-unique-id-abc123"
    }
  }
}
```

## Service Control Policies (SCPs)

SCPs restrict what **all** principals in member accounts can do. Since Sep 2025, SCPs support the full IAM policy language including conditions, individual resource ARNs, NotAction with Allow, and wildcards in Action strings:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyRegionsOutsideUS",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2"]
        },
        "ArnNotLike": {
          "aws:PrincipalARN": "arn:aws:iam::*:role/OrganizationAdmin"
        }
      }
    }
  ]
}
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `MaxSessionDuration` | 3600s | Max session for assumed role (up to 43200s) |
| `ExternalId` | None | Required for third-party trust relationships |
| `MFA Required` | No | Add `aws:MultiFactorAuthPresent` condition |
| `SourceIdentity` | None | Track original identity through role chains |

## Multi-Account Best Practices

1. **Use Organizations** -- centralize billing, SCPs, consolidated management
2. **Dedicated security account** -- CloudTrail, GuardDuty, Security Hub
3. **Shared services account** -- CI/CD, shared resources
4. **Restrict :root in trust policies** -- use specific role ARNs
5. **Require OrgID condition** -- prevent access from outside your org
6. **Enable CloudTrail** -- audit all cross-account role assumptions

## See Also

- [Roles](../concepts/roles.md) -- trust policy mechanics
- [STS and Federation](../concepts/sts-federation.md) -- AssumeRole API details
- [Permissions Boundaries](../concepts/permissions-boundaries.md) -- capping cross-account permissions
