# Secret Versioning

> **Purpose**: Understand version stages and how Secrets Manager tracks secret history
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Every time a secret value changes, Secrets Manager creates a new version identified by a UUID. Versions are labeled with staging labels (AWSCURRENT, AWSPREVIOUS, AWSPENDING) that control which version is returned by default. This versioning enables safe rotation with automatic rollback capability.

## Version Stages

```
┌─────────────────────────────────────────────┐
│ Secret: prod/myapp/db-credentials           │
├─────────────┬───────────┬───────────────────┤
│ Version ID  │ Stage     │ Created           │
├─────────────┼───────────┼───────────────────┤
│ abc-111     │ AWSCURRENT│ 2026-02-12        │
│ abc-000     │ AWSPREVIOUS│ 2026-01-12       │
│ abc-222     │ AWSPENDING│ (rotation active) │
└─────────────┴───────────┴───────────────────┘
```

| Stage | Behavior |
|-------|----------|
| **AWSCURRENT** | Default version returned by `GetSecretValue` |
| **AWSPREVIOUS** | Prior version, kept for rollback |
| **AWSPENDING** | Set during rotation, promoted to AWSCURRENT on success |

## The Pattern

```python
import boto3

client = boto3.client("secretsmanager")

# Get current version (default)
current = client.get_secret_value(SecretId="prod/myapp/db-credentials")
print(current["VersionId"])       # UUID of AWSCURRENT
print(current["VersionStages"])   # ["AWSCURRENT"]

# Get previous version explicitly
previous = client.get_secret_value(
    SecretId="prod/myapp/db-credentials",
    VersionStage="AWSPREVIOUS"
)

# Get specific version by ID
specific = client.get_secret_value(
    SecretId="prod/myapp/db-credentials",
    VersionId="abc-000-version-uuid"
)
```

## Version Lifecycle During Rotation

1. **createSecret** - New version created with `AWSPENDING` label
2. **setSecret** - New credentials applied to target (e.g., database)
3. **testSecret** - Verify new credentials work
4. **finishSecret** - Move `AWSCURRENT` to new version, `AWSPREVIOUS` to old

```python
# During rotation, the Lambda moves labels:
client.update_secret_version_stage(
    SecretId="prod/myapp/db-credentials",
    VersionStage="AWSCURRENT",
    MoveToVersionId=new_version_id,
    RemoveFromVersionId=current_version_id
)
```

## Describe Secret Metadata

```python
# Get version info without retrieving the actual secret value
metadata = client.describe_secret(SecretId="prod/myapp/db-credentials")
for version_id, stages in metadata["VersionIdsToStages"].items():
    print(f"  {version_id}: {stages}")
```

## Quick Reference

| Operation | Stage Effect |
|-----------|-------------|
| `create_secret()` | New version → AWSCURRENT |
| `put_secret_value()` | New version → AWSCURRENT, old → AWSPREVIOUS |
| `rotate_secret()` start | New version → AWSPENDING |
| `rotate_secret()` finish | AWSPENDING → AWSCURRENT, old AWSCURRENT → AWSPREVIOUS |

## Common Mistakes

### Wrong

```python
# Assuming version IDs are sequential or predictable
secret = client.get_secret_value(SecretId="my-secret", VersionId="v2")
```

### Correct

```python
# Use version stages, not version IDs, for retrieval
secret = client.get_secret_value(
    SecretId="my-secret",
    VersionStage="AWSCURRENT"  # or "AWSPREVIOUS"
)
```

## Related

- [Secrets Overview](../concepts/secrets-overview.md)
- [Rotation](../concepts/rotation.md)
