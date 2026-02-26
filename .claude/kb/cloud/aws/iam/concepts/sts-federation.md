# STS and Federation

> **Purpose**: Temporary credentials, SAML/OIDC federation, and AWS Identity Center
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

AWS Security Token Service (STS) provides temporary, limited-privilege credentials for IAM roles. Federation allows external identities (corporate directories, GitHub, Google) to access AWS without creating IAM users. Identity Center (formerly SSO) is the recommended entry point for human workforce access.

## STS API Actions

| API | Use Case | Principal Type |
|-----|----------|---------------|
| `AssumeRole` | Cross-account, service assumption | IAM user/role |
| `AssumeRoleWithSAML` | SAML 2.0 federation | Corporate IdP |
| `AssumeRoleWithWebIdentity` | OIDC federation | GitHub, Google, Cognito |
| `GetSessionToken` | MFA-protected API calls | IAM user with MFA |
| `GetFederationToken` | Custom federation broker | IAM user |
| `GetCallerIdentity` | Verify current identity | Any principal |

## AssumeRole Flow

```
1. Principal calls sts:AssumeRole with target role ARN
2. STS checks trust policy on target role
3. STS checks caller's identity-based policies for sts:AssumeRole
4. If both allow, STS returns temporary credentials:
   - AccessKeyId (starts with ASIA)
   - SecretAccessKey
   - SessionToken (required for all API calls)
   - Expiration
```

```python
import boto3

sts = boto3.client("sts")

# Verify who you are
identity = sts.get_caller_identity()
print(f"Account: {identity['Account']}, ARN: {identity['Arn']}")

# Assume a role
response = sts.assume_role(
    RoleArn="arn:aws:iam::987654321098:role/DataEngineerRole",
    RoleSessionName="etl-pipeline",
    DurationSeconds=3600,
    Tags=[{"Key": "Project", "Value": "data-lake"}]
)
```

## OIDC Federation (GitHub Actions)

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:my-org/my-repo:ref:refs/heads/main"
      }
    }
  }]
}
```

## SAML 2.0 Federation

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::123456789012:saml-provider/MyCorpIdP"
    },
    "Action": "sts:AssumeRoleWithSAML",
    "Condition": {
      "StringEquals": {
        "SAML:aud": "https://signin.aws.amazon.com/saml"
      }
    }
  }]
}
```

## AWS Identity Center (SSO)

The recommended approach for human workforce access:

- Centralized user management across all accounts
- Supports external IdPs (Okta, Azure AD, Google Workspace)
- Permission sets define access per account
- No long-lived credentials; uses STS behind the scenes
- CLI access via `aws sso login --profile profile-name`

## Session Tags

Pass tags during role assumption for ABAC:

```python
sts.assume_role(
    RoleArn="arn:aws:iam::123:role/DataRole",
    RoleSessionName="pipeline",
    Tags=[
        {"Key": "Project", "Value": "analytics"},
        {"Key": "CostCenter", "Value": "12345"}
    ]
)
```

Then reference in policies as `${aws:PrincipalTag/Project}`.

## Common Mistakes

### Wrong
```bash
# Hard-coding long-lived credentials in CI/CD
export AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=secret
```

### Correct
```yaml
# GitHub Actions: use OIDC federation
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
    aws-region: us-east-1
```

## Trusted Identity Propagation (TIP) SDK Plugins (Apr 2025)

TIP enables workforce identity context to flow through AWS services. SDK plugins for Java 2.0 and JavaScript v3 pass user identity through service calls, enabling downstream authorization based on the original user. Works with Identity Center and external IdPs.

## Related

- [Roles](roles.md) -- trust policies and role types
- [Principals and Identities](principals-identities.md) -- identity types overview
- [Cross-Account Access](../patterns/cross-account-access.md) -- multi-account federation
