# Dagster Cloud (Dagster+)

> **Purpose**: Managed orchestration platform with branch deployments, alerts, and insights
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Dagster+ is a managed orchestration platform. For dbt+Snowflake workloads, Serverless is recommended — Dagster only handles orchestration while compute runs in Snowflake.

## Deployment Options

| Option | Execution | Best For |
|--------|-----------|----------|
| **Serverless** | Dagster-managed | dbt + Snowflake, light orchestration |
| **Hybrid** | Your infrastructure | Heavy compute, data residency |

## Serverless Setup for dbt Projects

### 1. Configuration Files

```yaml
# dagster_cloud.yaml (repo root)
locations:
  - location_name: dbt-orchestration-hub
    code_source:
      module_name: dagster_orchestration.definitions
    build:
      directory: .
```

```toml
# pyproject.toml — required [tool.dagster] block
[tool.dagster]
module_name = "dagster_orchestration.definitions"
code_location_name = "dbt-orchestration-hub"
```

### 2. Environment Variables (Dagster Cloud UI)

Set in **Deployment > Environment variables**:

| Variable | Secret? | Notes |
|----------|---------|-------|
| `DBT_SNOWFLAKE_ACCOUNT` | No | e.g., `ava67570.east-us-2.azure` |
| `DBT_SNOWFLAKE_USER` | No | Service account |
| `DBT_SNOWFLAKE_PRIVATE_KEY_CONTENT` | **Yes** | Base64-encoded .p8 key |
| `DBT_SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` | **Yes** | Key passphrase |

### 3. Private Key Bridge Pattern

Cloud has no filesystem for `.p8` files. Bridge in `project.py`:
- Decode `DBT_SNOWFLAKE_PRIVATE_KEY_CONTENT` (base64) → temp file
- Set `DBT_SNOWFLAKE_PRIVATE_KEY_PATH` → profiles.yml works unchanged

### 4. CI/CD Manifest Build

```yaml
# In dagster-plus-deploy.yml, after "Initialize build session"
- name: Prepare dbt project for deployment
  if: steps.prerun.outputs.result == 'pex-deploy'
  run: |
    cd project-repo
    uv run dagster-dbt project prepare-and-package \
      --file dagster_orchestration/project.py
```

No Snowflake secrets needed — profiles.yml has dummy defaults.

### 5. GitHub Secrets

Only one secret needed: `DAGSTER_CLOUD_API_TOKEN`

## Branch Deployments

Automatic per PR:
- Isolated preview environment
- "View in Cloud" link in PR comments
- Schedules/sensors paused (prevents duplicate runs)
- Auto-deleted on PR close/merge

## UI Overhaul (Sep 2025)

- Redesigned homepage with asset health overview and freshness monitoring
- Customizable dashboards for team-specific views
- Improved asset graph navigation and filtering

## Dagster+ Insights (Beta)

Historical usage trends and per-asset cost attribution. Track compute hours, run duration trends, and identify expensive assets.

## Dagster+ Cost Insights

Track external costs per asset/run:
- **Snowflake**: Credits consumed per asset materialization
- **Compute**: CPU/memory usage attribution
- **AI costs**: LLM token costs per asset (OpenAI, Anthropic)

## Compass (Feb 2026)

AI-powered analytics over Dagster operational data. Query with natural language:
- "Which assets failed most this week?"
- "Show me the slowest materializations"
- "What's the cost trend for my dbt models?"

## Serverless Limitations

- Max 4 CPU, 16GB RAM per run
- 4-hour max run duration
- Fine for dbt (compute is in Snowflake, not Dagster)

## Common Mistakes

### Wrong

```python
# Storing private key path that doesn't exist in Cloud
private_key_path: "{{ env_var('DBT_SNOWFLAKE_PRIVATE_KEY_PATH') }}"
# Fails in Cloud: no filesystem, env var not set
```

### Correct

```python
# project.py bridges the gap automatically
# profiles.yml stays the same, project.py creates temp file from base64 content
private_key_path: "{{ env_var('DBT_SNOWFLAKE_PRIVATE_KEY_PATH', 'dummy.p8') }}"
```

## Related

- [dbt-integration](../patterns/dbt-integration.md)
- [project-structure](../patterns/project-structure.md)
- [definitions](../concepts/definitions.md)
