# IAM Conditions

> **Purpose**: Context-aware access control using condition keys and operators
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The `Condition` element in IAM policies adds context-based restrictions beyond Action and Resource. Conditions evaluate request attributes like source IP, time, tags, MFA status, and more. They are the key mechanism for enforcing attribute-based access control (ABAC).

## Condition Block Structure

```json
"Condition": {
  "Operator": {
    "ConditionKey": ["Value1", "Value2"]
  }
}
```

Multiple conditions in the same block use AND logic. Multiple values for the same key use OR logic.

```json
"Condition": {
  "StringEquals": {
    "aws:RequestedRegion": ["us-east-1", "us-west-2"],
    "aws:PrincipalTag/Department": "engineering"
  }
}
```

This means: (region is us-east-1 OR us-west-2) AND (department tag is engineering).

## Condition Operators

| Operator | Type | Use |
|----------|------|-----|
| `StringEquals` | Exact string | Tags, regions, account IDs |
| `StringNotEquals` | Negation | Exclude specific values |
| `StringLike` | Wildcard (`*`, `?`) | Prefix matching, patterns |
| `ArnEquals` / `ArnLike` | ARN comparison | Source ARN matching |
| `IpAddress` | CIDR | Network restrictions |
| `Bool` | Boolean | MFA, secure transport |
| `NumericLessThan` | Numeric | Rate limits, counts |
| `DateGreaterThan` | Date/time | Time-based access |
| `Null` | Key exists check | Require condition key presence |

Add `IfExists` suffix to any operator to skip check when key is absent: `StringEqualsIfExists`.

## Global Condition Keys

```json
// Restrict to specific regions
"Condition": { "StringEquals": { "aws:RequestedRegion": "us-east-1" } }

// Require MFA
"Condition": { "Bool": { "aws:MultiFactorAuthPresent": "true" } }

// Restrict to VPC
"Condition": { "StringEquals": { "aws:SourceVpc": "vpc-abc123" } }

// Restrict to Organization
"Condition": { "StringEquals": { "aws:PrincipalOrgID": "o-abc123" } }

// Source IP restriction
"Condition": { "IpAddress": { "aws:SourceIp": "203.0.113.0/24" } }

// Require secure transport
"Condition": { "Bool": { "aws:SecureTransport": "true" } }
```

## ABAC (Tag-Based Access Control)

Use tags on principals and resources for dynamic, scalable access:

```json
{
  "Effect": "Allow",
  "Action": ["ec2:StartInstances", "ec2:StopInstances"],
  "Resource": "arn:aws:ec2:*:*:instance/*",
  "Condition": {
    "StringEquals": {
      "aws:ResourceTag/Project": "${aws:PrincipalTag/Project}"
    }
  }
}
```

This allows users to manage only EC2 instances tagged with the same `Project` value as their own principal tag.

## Service-Specific Condition Keys

| Service | Key | Example Use |
|---------|-----|-------------|
| S3 | `s3:prefix` | Limit ListBucket to specific prefix |
| S3 | `s3:x-amz-server-side-encryption` | Require encryption on PutObject |
| EC2 | `ec2:ResourceTag/Environment` | Tag-based instance control |
| Lambda | `lambda:FunctionArn` | Restrict invoke to specific functions |
| STS | `sts:ExternalId` | Third-party cross-account access |

## Common Mistakes

### Wrong
```json
// Forgetting Null check -- condition is skipped if key is absent
"Condition": { "StringEquals": { "aws:PrincipalTag/Team": "data" } }
// A principal WITHOUT the tag bypasses this condition!
```

### Correct
```json
// Add Null check to enforce tag presence
"Condition": {
  "StringEquals": { "aws:PrincipalTag/Team": "data" },
  "Null": { "aws:PrincipalTag/Team": "false" }
}
```

## Conditions in SCPs (Sep 2025)

SCPs now support the full condition block syntax. Previously, SCPs had limited condition support. Now you can use:

- All global condition keys (`aws:RequestedRegion`, `aws:PrincipalTag/*`, `aws:SourceIp`, etc.)
- All condition operators (`StringEquals`, `ArnLike`, `IpAddress`, etc.)
- This enables fine-grained Organization guardrails such as region restrictions with role exceptions

```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": { "aws:RequestedRegion": ["us-east-1", "us-west-2"] },
    "ArnNotLike": { "aws:PrincipalARN": "arn:aws:iam::*:role/OrgAdmin" }
  }
}
```

## Related

- [Policies](policies.md) -- policy structure and evaluation
- [Least Privilege](../patterns/least-privilege.md) -- conditions as least-privilege tool
- [Cross-Account Access](../patterns/cross-account-access.md) -- ExternalId condition
