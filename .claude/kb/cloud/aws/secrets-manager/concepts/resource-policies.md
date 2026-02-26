# Resource Policies and Access Control

> **Purpose**: Understand IAM and resource-based policies for Secrets Manager access control
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Access to secrets is controlled through two mechanisms: IAM identity-based policies (attached to users/roles) and resource-based policies (attached to secrets). Resource policies enable cross-account access and fine-grained control without modifying IAM policies. Tag-based access control (ABAC) provides scalable permissions.

## Identity-Based Policy (IAM)

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/*"
        }
    ]
}
```

## Resource-Based Policy (on Secret)

```python
import boto3, json

client = boto3.client("secretsmanager")

policy = {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::987654321098:role/AppRole"
            },
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "*"
        }
    ]
}

client.put_resource_policy(
    SecretId="prod/myapp/db-credentials",
    ResourcePolicy=json.dumps(policy)
)
```

## Tag-Based Access Control (ABAC)

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["secretsmanager:GetSecretValue"],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "secretsmanager:ResourceTag/Environment": "${aws:PrincipalTag/Environment}"
                }
            }
        }
    ]
}
```

Tag the secret: `Environment=prod`, and the role: `Environment=prod`. Access is granted only when tags match.

## Key IAM Actions

| Action | Use |
|--------|-----|
| `secretsmanager:CreateSecret` | Create new secrets |
| `secretsmanager:GetSecretValue` | Retrieve secret value |
| `secretsmanager:PutSecretValue` | Update secret value |
| `secretsmanager:DeleteSecret` | Delete a secret |
| `secretsmanager:DescribeSecret` | Get metadata (no value) |
| `secretsmanager:ListSecrets` | List all secrets |
| `secretsmanager:RotateSecret` | Trigger rotation |
| `secretsmanager:TagResource` | Add tags |
| `secretsmanager:PutResourcePolicy` | Attach resource policy |

## Least Privilege Examples

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ReadOnlyAppAccess",
            "Effect": "Allow",
            "Action": ["secretsmanager:GetSecretValue"],
            "Resource": [
                "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/myapp/*"
            ]
        }
    ]
}
```

## VPC Endpoint Policy

Restrict Secrets Manager access to specific VPC:

```json
{
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:sourceVpc": "vpc-0123456789abcdef0"
                }
            }
        }
    ]
}
```

## Common Mistakes

### Wrong

```json
{"Action": "secretsmanager:*", "Resource": "*"}
```

### Correct

```json
{"Action": ["secretsmanager:GetSecretValue"], "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/myapp/*"}
```

## Related

- [Encryption and KMS](../concepts/encryption-kms.md)
- [Cross-Account Access](../patterns/cross-account-access.md)
