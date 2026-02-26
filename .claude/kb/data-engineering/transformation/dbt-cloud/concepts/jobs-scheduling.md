# Jobs and Scheduling

> **Purpose**: Configure job execution, scheduling, and orchestration
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Jobs are sets of dbt commands that run on a schedule, via API, or triggered by events. The dbt Cloud scheduler handles cron-based execution, event-driven triggers, and CI jobs. Jobs run in deployment environments (now using Release Tracks instead of version pinning) and produce artifacts for downstream use.

## Job Types

| Type | Trigger | Use Case |
|------|---------|----------|
| Scheduled | Cron expression | Regular data refreshes |
| CI | Pull request | Test changes before merge |
| Merge | PR merge | Deploy after merge |
| API-triggered | External system | Event-driven workflows |

## Job Configuration

```yaml
# Job settings in dbt Cloud UI or API
name: "Daily Production Run"
environment: production
commands:
  - dbt source freshness
  - dbt build --select state:modified+
  - dbt run-operation upload_artifacts
schedule:
  cron: "0 6 * * *"  # 6 AM daily
```

## Scheduling Options

| Method | Example | Use Case |
|--------|---------|----------|
| Cron | `0 */2 * * *` | Every 2 hours |
| Interval | Every 6 hours | Simple recurring |
| Day/Time | Mon-Fri 8 AM | Business hours |

## Job Chaining

```yaml
# Trigger downstream job on completion
on_success:
  trigger_job: downstream_job_id
on_failure:
  notification: slack_channel
```

## Run Artifacts

| Artifact | Purpose |
|----------|---------|
| `manifest.json` | Model metadata, dependencies |
| `run_results.json` | Execution status, timing |
| `sources.json` | Source freshness results |
| `catalog.json` | Column metadata, stats |

## Commands in Jobs

```bash
# Common job command sequences
dbt source freshness
dbt build
dbt docs generate

# Selective runs
dbt build --select tag:daily
dbt build --select state:modified+ --defer
```

## Common Mistakes

### Wrong

```bash
# Running everything always
dbt run
dbt test
```

### Correct

```bash
# Efficient: build in DAG order, use state
dbt build --select state:modified+
```

## Related

- [CI/CD Workflow](../patterns/ci-cd-workflow.md)
- [projects-environments](projects-environments.md)
