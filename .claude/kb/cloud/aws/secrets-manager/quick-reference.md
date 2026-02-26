# AWS Secrets Manager Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Core API Operations

| Operation | Boto3 Method | Permission Required |
|-----------|-------------|---------------------|
| Create secret | `create_secret()` | `secretsmanager:CreateSecret` |
| Get value | `get_secret_value()` | `secretsmanager:GetSecretValue` |
| Batch get | `batch_get_secret_value()` | `secretsmanager:BatchGetSecretValue` |
| Update value | `put_secret_value()` | `secretsmanager:PutSecretValue` |
| Update metadata | `update_secret()` | `secretsmanager:UpdateSecret` |
| Delete secret | `delete_secret()` | `secretsmanager:DeleteSecret` |
| Rotate | `rotate_secret()` | `secretsmanager:RotateSecret` |
| Describe | `describe_secret()` | `secretsmanager:DescribeSecret` |
| List secrets | `list_secrets()` | `secretsmanager:ListSecrets` |
| Tag | `tag_resource()` | `secretsmanager:TagResource` |

## Version Stages

| Stage | Meaning | When Set |
|-------|---------|----------|
| `AWSCURRENT` | Active version | After creation or rotation completes |
| `AWSPREVIOUS` | Prior version | When AWSCURRENT moves to new version |
| `AWSPENDING` | Rotation in progress | During rotation, before finalize step |

## Rotation Strategies

| Strategy | Use Case | Users Required |
|----------|----------|---------------|
| Single user | Simple apps, non-critical | 1 |
| Alternating users | Zero-downtime, production | 2 (user + clone) |
| Managed rotation | RDS, Redshift, DocumentDB | 1 (AWS managed) |
| Managed External Secrets | SaaS (Salesforce, BigID, Snowflake) | 0 (no Lambda needed, Nov 2025) |

## Pricing (per secret/month)

| Item | Cost |
|------|------|
| Per secret | $0.40/month |
| Per 10,000 API calls | $0.05 |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Simple key-value storage | Secrets Manager or Parameter Store |
| Automatic rotation needed | Secrets Manager |
| Database credentials | Secrets Manager (managed rotation) |
| Config values (non-secret) | Systems Manager Parameter Store |
| Cross-region availability | Secrets Manager (replication) |
| Cost-sensitive, no rotation | Parameter Store SecureString |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Hardcode secrets in source | Retrieve at runtime via SDK |
| Call API on every request | Use client-side caching library |
| Use `aws/secretsmanager` CMK for cross-account | Use customer-managed KMS key |
| Skip `recovery_window_in_days` in Terraform | Set explicitly (7-30 days) |
| Store large blobs (>64KB) | Use S3 with encrypted references |

## CLI Quick Commands

| Task | Command |
|------|---------|
| Create | `aws secretsmanager create-secret --name MySecret --secret-string '{"user":"admin"}'` |
| Get | `aws secretsmanager get-secret-value --secret-id MySecret` |
| Rotate | `aws secretsmanager rotate-secret --secret-id MySecret` |
| Delete | `aws secretsmanager delete-secret --secret-id MySecret --recovery-window-in-days 7` |
| List | `aws secretsmanager list-secrets` |

## Related Documentation

| Topic | Path |
|-------|------|
| Getting Started | `concepts/secrets-overview.md` |
| Full Index | `index.md` |
