# AWS IAM Quick Reference

## Policy Structure

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DescriptiveName",
    "Effect": "Allow|Deny",
    "Action": ["service:Action"],
    "Resource": ["arn:aws:service:region:account:resource"],
    "Condition": { "Operator": { "key": ["value"] } }
  }]
}
```

## Common CLI Commands

| Command | Description |
|---------|-------------|
| `aws iam create-role --role-name X --assume-role-policy-document file://trust.json` | Create role |
| `aws iam attach-role-policy --role-name X --policy-arn arn:aws:iam::aws:policy/Y` | Attach managed policy |
| `aws iam put-role-policy --role-name X --policy-name Y --policy-document file://p.json` | Inline policy |
| `aws iam create-policy --policy-name X --policy-document file://p.json` | Create managed policy |
| `aws sts assume-role --role-arn arn:aws:iam::123:role/X --role-session-name Y` | Assume role |
| `aws iam get-role --role-name X` | Inspect role |
| `aws iam list-attached-role-policies --role-name X` | List role policies |
| `aws iam simulate-principal-policy --policy-source-arn ARN --action-names s3:GetObject` | Test policy |
| `aws accessanalyzer create-analyzer --analyzer-name X --type ACCOUNT` | Create Access Analyzer |

## Policy Types

| Type | Attached To | Purpose |
|------|-------------|---------|
| Identity-based | User/Group/Role | Grant permissions to principal |
| Resource-based | S3/SQS/Lambda/etc | Grant cross-account or service access |
| Permissions boundary | User/Role | Cap maximum allowed permissions |
| SCP | OU/Account | Organization-wide guardrails (full IAM policy language since Sep 2025) |
| Session policy | STS session | Further restrict assumed role |
| ACL | S3/VPC | Legacy coarse-grained access |

## Condition Operators

| Operator | Use Case | Example |
|----------|----------|---------|
| `StringEquals` | Exact match | `"aws:RequestedRegion": "us-east-1"` |
| `StringLike` | Wildcard match | `"s3:prefix": ["home/${aws:username}/*"]` |
| `ArnLike` | ARN pattern | `"aws:SourceArn": "arn:aws:s3:::my-bucket"` |
| `IpAddress` | Network restriction | `"aws:SourceIp": "203.0.113.0/24"` |
| `Bool` | Boolean check | `"aws:MultiFactorAuthPresent": "true"` |
| `DateGreaterThan` | Time-based | `"aws:CurrentTime": "2026-01-01T00:00:00Z"` |
| `NumericLessThan` | Numeric check | `"s3:max-keys": "100"` |

## Common Global Condition Keys

| Key | Description |
|-----|-------------|
| `aws:SourceIp` | Requester IP address |
| `aws:SourceVpc` | VPC the request originates from |
| `aws:PrincipalOrgID` | AWS Organization ID |
| `aws:PrincipalTag/key` | Tag on the calling principal |
| `aws:RequestedRegion` | Target region of the API call |
| `aws:MultiFactorAuthPresent` | Whether MFA was used |
| `aws:CalledVia` | Service that made the request on behalf of principal |

## Trust Policy Template (Role)

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

## Evaluation Logic (Simplified)

1. **Explicit Deny** wins over everything
2. **SCP** must allow (if in Organization)
3. **Permissions boundary** must allow (if set)
4. **Identity-based** OR **resource-based** policy must allow
5. **Session policy** must allow (if STS session)
6. Default: **implicit deny**

## ARN Format

```
arn:aws:iam::<account-id>:user/path/username
arn:aws:iam::<account-id>:role/path/rolename
arn:aws:iam::<account-id>:policy/path/policyname
arn:aws:iam::aws:policy/AWSmanagedPolicyName
arn:aws:sts::<account-id>:assumed-role/rolename/session
```
