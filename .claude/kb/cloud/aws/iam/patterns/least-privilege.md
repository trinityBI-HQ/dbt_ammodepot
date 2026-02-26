# Least Privilege Patterns

> **Purpose**: Practical strategies for granting minimum required permissions
> **MCP Validated**: 2026-02-19

## When to Use

- Every new IAM policy (this should be default practice)
- Auditing existing overly-permissive policies
- Refining `*` wildcards to specific actions and resources
- Preparing for compliance audits (SOC2, HIPAA, PCI-DSS)

## Strategy 1: Start Narrow, Expand on Failure

Begin with zero permissions. Add only what fails with `AccessDenied`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ReadSpecificPrefix",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::data-lake-prod",
        "arn:aws:s3:::data-lake-prod/raw/invoices/*"
      ],
      "Condition": {
        "StringLike": {
          "s3:prefix": ["raw/invoices/*"]
        }
      }
    }
  ]
}
```

## Strategy 2: Use IAM Access Analyzer

Access Analyzer generates policies based on actual CloudTrail activity:

```bash
# Create analyzer
aws accessanalyzer create-analyzer \
  --analyzer-name account-analyzer \
  --type ACCOUNT

# Generate policy from 90 days of CloudTrail activity
aws accessanalyzer start-policy-generation \
  --policy-generation-details '{
    "principalArn": "arn:aws:iam::123456789012:role/MyRole"
  }'

# Get the generated policy
aws accessanalyzer get-generated-policy \
  --job-id "job-id-from-above"
```

## Strategy 3: Separate Roles by Responsibility

```
Lambda-Reader-Role    -> s3:GetObject, dynamodb:GetItem
Lambda-Writer-Role    -> s3:PutObject, dynamodb:PutItem
Deploy-Role           -> lambda:UpdateFunctionCode, s3:PutObject
Monitoring-Role       -> cloudwatch:GetMetricData, logs:FilterLogEvents
```

Never combine deployment and runtime permissions in one role.

## Strategy 4: Resource-Level Restrictions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LambdaInvokeSpecific",
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": "arn:aws:lambda:us-east-1:123456789012:function:process-*"
    },
    {
      "Sid": "DynamoDBScopedAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-east-1:123456789012:table/orders",
        "arn:aws:dynamodb:us-east-1:123456789012:table/orders/index/*"
      ]
    }
  ]
}
```

## Strategy 5: Condition-Based Scoping

```json
{
  "Sid": "RegionLocked",
  "Effect": "Allow",
  "Action": ["ec2:*", "rds:*"],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:RequestedRegion": ["us-east-1", "us-west-2"]
    }
  }
}
```

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| `"Action": "*"` | Admin access to everything | List specific actions |
| `"Resource": "*"` | All resources in account | Use resource ARNs |
| Shared roles across services | Blast radius too large | One role per service |
| Copy-paste from Stack Overflow | Untested, overly broad | Audit before use |
| "Temporary" admin access | Becomes permanent | Use time-bound sessions |

## Strategy 6: IAM Policy Autopilot (Nov 2025)

An open-source MCP (Model Context Protocol) server that analyzes your application code and generates least-privilege IAM policies automatically:

- Scans source code to identify AWS API calls
- Generates precise IAM policies matching actual usage
- Integrates with development tools via MCP protocol
- Eliminates manual policy creation and over-permissioning

```bash
# Install and run Policy Autopilot MCP server
# It analyzes your codebase and generates IAM policies
# See: https://github.com/aws/iam-policy-autopilot
```

Key benefits:
- **No CloudTrail delay**: Works from source code, not historical activity
- **Pre-deployment**: Generate policies before first deployment
- **Precise resource scoping**: Identifies specific resource ARNs from code

## Audit Checklist

- [ ] No `*` in Action (except for read-only monitoring roles)
- [ ] No `*` in Resource
- [ ] Conditions applied where possible (region, IP, tags)
- [ ] Separate roles for separate responsibilities
- [ ] Unused permissions removed (check Access Advisor)
- [ ] Permissions boundary set for developer-created roles
- [ ] Policy Autopilot or Access Analyzer used for policy generation

## See Also

- [Policies](../concepts/policies.md) -- policy structure
- [Conditions](../concepts/conditions.md) -- condition-based restrictions
- [Terraform IAM](terraform-iam.md) -- codifying least-privilege policies
