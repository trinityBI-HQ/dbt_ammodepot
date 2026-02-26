# Secret Rotation

> **Purpose**: Understand automatic rotation strategies, schedules, and Lambda integration
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Secrets Manager can automatically rotate secrets on a schedule using Lambda functions. AWS provides managed rotation for RDS, Redshift, and DocumentDB, while custom Lambda functions handle other secret types. Rotation follows a four-step protocol: createSecret, setSecret, testSecret, finishSecret.

## Rotation Strategies

### Single User Rotation

One database user; credentials updated in-place. Brief connectivity gap possible during rotation.

```
Before: user=admin, password=OldPass (AWSCURRENT)
During: user=admin, password=NewPass (AWSPENDING)
After:  user=admin, password=NewPass (AWSCURRENT)
```

### Alternating Users Rotation

Two database users alternate; zero-downtime. Requires a "clone" user with identical permissions.

```
Before: user=admin_1, password=Pass1 (AWSCURRENT)
         user=admin_2, password=Pass2 (AWSPREVIOUS)
After:  user=admin_2, password=NewPass (AWSCURRENT)
         user=admin_1, password=Pass1 (AWSPREVIOUS)
```

### Managed Rotation

AWS handles rotation Lambda automatically for supported services:
- Amazon RDS (MySQL, PostgreSQL, Oracle, SQL Server, MariaDB)
- Amazon Aurora
- Amazon Redshift
- Amazon DocumentDB

### Managed External Secrets (Nov 2025)

Automatic rotation for third-party SaaS credentials without writing custom Lambda functions:

- **Salesforce** -- API tokens and OAuth credentials
- **BigID** -- Data intelligence platform credentials
- **Snowflake** -- Database user credentials

No Lambda development, deployment, or VPC configuration required. AWS manages the entire rotation lifecycle for these supported third-party services.

## Rotation Schedule

```python
import boto3

client = boto3.client("secretsmanager")

# Enable rotation with schedule expression
client.rotate_secret(
    SecretId="prod/myapp/db-credentials",
    RotationLambdaARN="arn:aws:lambda:us-east-1:123456789012:function:rotate-db",
    RotationRules={
        "ScheduleExpression": "rate(30 days)",  # or cron()
        "Duration": "2h"  # rotation window
    }
)
```

| Schedule Type | Example | Use Case |
|---------------|---------|----------|
| Rate | `rate(30 days)` | Fixed interval |
| Cron | `cron(0 8 1 * ? *)` | Specific time (1st of month, 8AM) |
| Duration window | `"Duration": "4h"` | Max rotation window |

## Four-Step Rotation Protocol

The Lambda function implements four steps, each invoked separately:

```python
def lambda_handler(event, context):
    step = event["Step"]
    secret_id = event["SecretId"]
    token = event["ClientRequestToken"]

    if step == "createSecret":
        # Generate new credential, store as AWSPENDING
        pass
    elif step == "setSecret":
        # Apply new credential to the target service
        pass
    elif step == "testSecret":
        # Verify new credential works
        pass
    elif step == "finishSecret":
        # Move AWSPENDING to AWSCURRENT
        pass
```

## Required Lambda Permissions

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:PutSecretValue",
                "secretsmanager:UpdateSecretVersionStage"
            ],
            "Resource": "arn:aws:secretsmanager:*:*:secret:prod/*"
        },
        {
            "Effect": "Allow",
            "Action": ["secretsmanager:GetRandomPassword"],
            "Resource": "*"
        }
    ]
}
```

## Common Mistakes

### Wrong

```python
# No network access — Lambda in VPC without NAT/VPC endpoint
rotation_lambda_in_vpc_without_endpoint = True  # Rotation will timeout
```

### Correct

```python
# Lambda needs access to both Secrets Manager API and target database
# Option 1: VPC endpoint for Secrets Manager + DB in same VPC
# Option 2: Lambda outside VPC with public Secrets Manager endpoint
```

## Related

- [Versioning](../concepts/versioning.md)
- [Lambda Rotation Pattern](../patterns/lambda-rotation.md)
