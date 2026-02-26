# Key Policies

> **Purpose**: Resource-based access control for KMS keys, grants, and ViaService conditions
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Every KMS key has exactly one key policy -- a resource-based policy that is the primary mechanism for controlling access to the key. Unlike most AWS resources where IAM policies alone grant access, KMS requires the key policy to explicitly allow access before IAM policies can take effect.

## Key Policy vs IAM Policy

| Aspect | Key Policy | IAM Policy |
|--------|-----------|------------|
| Attached to | KMS key | IAM principal |
| Required | Yes (exactly one) | Optional |
| Cross-account | Enables directly | Requires key policy to allow first |
| Grants | Defined in key policy | Cannot create grants |

**Critical rule**: If the key policy does not allow IAM policies to be used, then IAM policies attached to the principal have no effect on that key.

## Default Key Policy

When you create a key, the default policy allows the root account full access and enables IAM policies:

```json
{
  "Sid": "EnableIAMPolicies",
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::123456789012:root" },
  "Action": "kms:*",
  "Resource": "*"
}
```

This single statement enables the IAM policy evaluation system for this key. Without it, only the key policy itself controls access.

## Separating Admin and Usage

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnableIAMPolicies",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::123456789012:root" },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "KeyAdmins",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::123456789012:role/KeyAdmin" },
      "Action": [
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
        "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
        "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
        "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KeyUsers",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::123456789012:role/AppRole" },
      "Action": [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
        "kms:GenerateDataKey*", "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
```

## Grants

Grants provide temporary, revocable key access without modifying the key policy:

```python
import boto3
kms = boto3.client("kms")

grant = kms.create_grant(
    KeyId="arn:aws:kms:us-east-1:123:key/KEY_ID",
    GranteePrincipal="arn:aws:iam::123:role/lambda-processor",
    Operations=["Encrypt", "Decrypt", "GenerateDataKey"],
    Constraints={
        "EncryptionContextEquals": {
            "Department": "Finance"
        }
    }
)
# Revoke later: kms.revoke_grant(KeyId=..., GrantId=grant["GrantId"])
```

| Grant Feature | Description |
|---------------|-------------|
| Operations | Encrypt, Decrypt, GenerateDataKey, ReEncrypt, Sign, Verify, etc. |
| Constraints | Restrict to specific encryption context |
| Retirement | Grant can be retired by grantee or retiring principal |
| No policy change | Avoids editing the key policy for temporary access |

## ViaService Condition

Restrict key usage to requests made through a specific AWS service:

```json
{
  "Sid": "AllowViaS3Only",
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::123456789012:role/AppRole" },
  "Action": ["kms:Decrypt", "kms:GenerateDataKey"],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "kms:ViaService": "s3.us-east-1.amazonaws.com"
    }
  }
}
```

## Common Mistakes

### Wrong
```json
// Key policy without root access -- locks yourself out!
{
  "Principal": { "AWS": "arn:aws:iam::123:role/OnlyThisRole" },
  "Action": "kms:*",
  "Resource": "*"
}
// If the role is deleted, the key becomes unmanageable
```

### Correct
```json
// Always include root account access as a safety net
{
  "Principal": { "AWS": "arn:aws:iam::123456789012:root" },
  "Action": "kms:*",
  "Resource": "*"
}
```

## Related

- [Key Types](key-types.md) -- customer-managed keys require key policies
- [Terraform KMS](../patterns/terraform-kms.md) -- key policy as code
