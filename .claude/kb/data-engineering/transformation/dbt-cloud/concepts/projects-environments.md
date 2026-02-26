# Projects and Environments

> **Purpose**: Understand dbt Cloud project structure and environment configuration
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A dbt project contains all the files and folders that define your data transformations. Environments determine how dbt executes your project, specifying the dbt version, warehouse connection, and target schema. Each project has one development environment and unlimited deployment environments.

## Project Structure

```yaml
# dbt_project.yml
name: 'my_project'
version: '1.0.0'
config-version: 2

profile: 'my_profile'
model-paths: ["models"]
seed-paths: ["seeds"]
test-paths: ["tests"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

models:
  my_project:
    staging:
      +materialized: view
    marts:
      +materialized: table
```

## Environment Types

| Type | Purpose | Count |
|------|---------|-------|
| Development | IDE work, personal schema | 1 per project |
| Deployment | Production, CI, staging | Unlimited |

## Release Tracks (replaces version pinning)

| Track | Description | Use Case |
|-------|-------------|----------|
| `Latest` | Newest features, earliest access | Dev environments |
| `Compatible` | Stable, recommended for production | Prod environments |
| `Extended` | Long-term support, security fixes | Regulated industries |
| `Latest Fusion` | Latest + Fusion Engine (preview) | Early adopters |

Environments now select a Release Track instead of a specific dbt version.
dbt versions 1.7 and below are no longer supported.

## Environment Configuration

```yaml
# Deployment environment settings
release_track: "compatible"  # Replaces dbt_version pinning
target_name: "prod"
schema: "analytics"
threads: 8
```

## Quick Reference

| Setting | Development | Deployment |
|---------|-------------|------------|
| Schema | User-specific | Configured |
| Threads | Lower (1-4) | Higher (8-16) |
| Target | dev | prod, staging, ci |

## Common Mistakes

### Wrong

```yaml
# Hardcoded schema everywhere
schema: "analytics_prod"
```

### Correct

```yaml
# Dynamic schema based on target
schema: "{{ target.schema }}"
```

## Related

- [models-materializations](models-materializations.md)
- [CI/CD Workflow](../patterns/ci-cd-workflow.md)
