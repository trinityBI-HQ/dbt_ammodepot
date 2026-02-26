# CI/CD Workflow Pattern

> **Purpose**: Automate testing and deployment with CI jobs, merge jobs, and webhooks
> **MCP Validated**: 2026-02-19

## When to Use

- Team collaboration with pull request reviews
- Need to catch breaking changes before merge
- Want automated deployment after code review
- Integration with external systems via webhooks

## Implementation

### CI Job Configuration

```yaml
# dbt Cloud CI Job Settings
name: "PR CI Check"
job_type: ci
environment: ci_environment
commands:
  - dbt build --select state:modified+ --defer --favor-state
run_generate_sources: true
run_lint: true  # SQL linting enabled

# Triggered automatically on PR creation/update
```

### Merge Job Configuration

```yaml
# dbt Cloud Merge Job Settings
name: "Post-Merge Deploy"
job_type: merge
environment: production
commands:
  - dbt build --select state:modified+
  - dbt docs generate
```

## CI Job Features

| Feature | Description |
|---------|-------------|
| Slim CI | Only builds modified models + downstream |
| Concurrent checks | Multiple PRs test simultaneously |
| Smart cancellation | Cancels stale runs on new commits |
| Defer to production | Uses prod artifacts for unchanged models |
| Release Tracks | Environments use tracks, not version pins |

## Webhook Integration

```json
// Outbound webhook payload (on job completion)
{
  "accountId": 12345,
  "jobId": 67890,
  "runId": 11111,
  "runStatus": "Success",
  "runStatusMessage": "Run completed successfully",
  "releaseTrack": "compatible",
  "environmentId": 22222
}
```

### Webhook Use Cases

```yaml
# Notify Slack on failure
webhook:
  event: job.run.completed
  condition: run_status == 'Error'
  destination: slack_channel

# Trigger downstream system on success
webhook:
  event: job.run.completed
  condition: run_status == 'Success'
  destination: orchestrator_api
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `defer` | false | Use production manifests for unchanged models |
| `state:modified` | - | Selector for changed models |
| `run_generate_sources` | false | Check source freshness in CI |

## State Comparison

```bash
# CI job commands using state
dbt build --select state:modified+ --defer --favor-state

# What state:modified includes:
# - Changed model SQL
# - Changed model config
# - Changed tests
# - Downstream dependencies (+)
```

## API Integration

```bash
# Trigger job via API
curl -X POST \
  -H "Authorization: Token ${DBT_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"cause": "Triggered by external system"}' \
  "https://cloud.getdbt.com/api/v2/accounts/${ACCOUNT_ID}/jobs/${JOB_ID}/run/"
```

## Example Usage

```yaml
# Complete CI/CD pipeline flow
1. Developer opens PR
2. CI job auto-triggers
   - Builds modified models in CI schema
   - Runs tests on modified models
   - Posts status check to GitHub
3. PR approved and merged
4. Merge job auto-triggers
   - Deploys changes to production
   - Generates documentation
5. Webhook notifies downstream systems
```

## See Also

- [jobs-scheduling](../concepts/jobs-scheduling.md)
- [Testing Strategy](testing-strategy.md)
