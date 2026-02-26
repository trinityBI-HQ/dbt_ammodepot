# Cross-Account Access Pattern

> **Purpose**: Share secrets securely across AWS accounts using resource policies and CMKs
> **MCP Validated**: 2026-02-19

## When to Use

- Shared services account stores secrets consumed by workload accounts
- Central security team manages credentials for multiple teams
- Multi-account AWS Organizations setup
- Partner or vendor credential sharing

## Implementation

### Account A (Secret Owner - 111111111111)

```python
import boto3
import json

sm_client = boto3.client("secretsmanager")

# Step 1: Create secret with customer-managed KMS key (required for cross-account)
secret_arn = sm_client.create_secret(
    Name="shared/api-credentials",
    SecretString=json.dumps({"api_key": "sk-abc123", "endpoint": "https://api.example.com"}),
    KmsKeyId="arn:aws:kms:us-east-1:111111111111:key/cmk-key-id",
)["ARN"]

# Step 2: Attach resource policy allowing Account B
policy = {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {"AWS": "arn:aws:iam::222222222222:role/AppRole"},
            "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
            "Resource": "*",
        }
    ],
}
sm_client.put_resource_policy(
    SecretId="shared/api-credentials",
    ResourcePolicy=json.dumps(policy),
)
```

### KMS Key Policy (Account A)

The KMS key must also grant decrypt access to Account B:

```json
{
    "Sid": "AllowCrossAccountDecrypt",
    "Effect": "Allow",
    "Principal": {
        "AWS": "arn:aws:iam::222222222222:role/AppRole"
    },
    "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
    ],
    "Resource": "*"
}
```

### Account B (Secret Consumer - 222222222222)

```python
import boto3
import json

# IAM policy on AppRole must allow secretsmanager:GetSecretValue
# on the cross-account secret ARN

sm_client = boto3.client("secretsmanager", region_name="us-east-1")

# Access secret using full ARN (name alone won't work cross-account)
response = sm_client.get_secret_value(
    SecretId="arn:aws:secretsmanager:us-east-1:111111111111:secret:shared/api-credentials-AbCdEf"
)
creds = json.loads(response["SecretString"])
```

### Account B IAM Policy

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
            "Resource": "arn:aws:secretsmanager:us-east-1:111111111111:secret:shared/*"
        },
        {
            "Effect": "Allow",
            "Action": ["kms:Decrypt", "kms:DescribeKey"],
            "Resource": "arn:aws:kms:us-east-1:111111111111:key/cmk-key-id"
        }
    ]
}
```

## Terraform Cross-Account Setup

```hcl
# Account A - Secret with resource policy
resource "aws_secretsmanager_secret" "shared" {
  name       = "shared/api-credentials"
  kms_key_id = aws_kms_key.cross_account.arn
}

resource "aws_secretsmanager_secret_policy" "cross_account" {
  secret_arn = aws_secretsmanager_secret.shared.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::222222222222:role/AppRole" }
      Action    = ["secretsmanager:GetSecretValue"]
      Resource  = "*"
    }]
  })
}
```

## Checklist

| Requirement | Location |
|-------------|----------|
| Customer-managed KMS key | Account A |
| KMS key policy grants decrypt to Account B | Account A |
| Secret resource policy grants GetSecretValue | Account A |
| IAM policy allows GetSecretValue on secret ARN | Account B |
| IAM policy allows kms:Decrypt on KMS key ARN | Account B |
| Use full secret ARN (not name) | Account B code |

## See Also

- [Resource Policies](../concepts/resource-policies.md)
- [Encryption and KMS](../concepts/encryption-kms.md)
- [Terraform Setup](../patterns/terraform-setup.md)
