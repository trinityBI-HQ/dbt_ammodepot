# Project Structure Pattern

> **Purpose**: Organizing Dagster + dbt monorepo for multi-client scalability
> **MCP Validated**: 2026-02-19

## When to Use

- Starting a Dagster + dbt project
- Multi-client monorepo with isolated dbt projects
- Deploying to Dagster Cloud Serverless
- Need event-driven sensors alongside scheduled builds

## Implementation — Multi-Client Monorepo

```text
dbt-orchestration-hub/
├── pyproject.toml                          # Python deps + [tool.dagster]
├── workspace.yaml                          # Local dev only
├── dagster_cloud.yaml                      # Dagster Cloud config
├── dagster_orchestration/                  # Dagster Python package
│   ├── __init__.py
│   ├── definitions.py                      # Top-level Definitions entry point
│   ├── project.py                          # DbtProject + env bridging
│   ├── assets.py                           # @dbt_assets per client
│   ├── resources.py                        # DbtCliResource + SnowflakeResource
│   ├── schedules.py                        # Cron schedules
│   └── sensors.py                          # Event-driven sensors
├── clients/
│   └── theraice/
│       └── dbt_project/                    # Isolated dbt project
│           ├── dbt_project.yml
│           ├── profiles.yml                # env_var() with dummy defaults
│           ├── .env                        # Local credentials (gitignored)
│           └── models/
│               ├── bronze/                 # 8 view models
│               ├── silver/                 # 7 table/incremental models
│               └── gold/                   # 4 table models
└── shared/
    └── dbt_macros/                         # Cross-client shared macros
```

## Configuration

| Phase | Structure |
|-------|-----------|
| 1 client | Single code location, flat dagster_orchestration/ |
| 2-3 clients | Add DbtProject per client in project.py |
| 4+ clients | Split into per-client code locations |

## Definitions Entry Point

```python
# definitions.py
from dagster import Definitions
from .assets import theraice_dbt_assets
from .resources import dbt_resource, snowflake_sensor_resource
from .schedules import daily_dbt_build
from .sensors import orders_stream_sensor

defs = Definitions(
    assets=[theraice_dbt_assets],
    schedules=[daily_dbt_build],
    sensors=[orders_stream_sensor],
    resources={"dbt": dbt_resource, "snowflake": snowflake_sensor_resource},
)
```

## Adding a New Client

1. Create `clients/acme/dbt_project/` with profiles.yml (dummy defaults)
2. Add `acme_project = DbtProject(...)` in `project.py`
3. Add `@dbt_assets(manifest=acme_project.manifest_path, name="acme")`
4. Add client-specific schedule/sensor
5. Register in `definitions.py`

## Required Config Files

```toml
# pyproject.toml
[tool.dagster]
module_name = "dagster_orchestration.definitions"
code_location_name = "dbt-orchestration-hub"

[tool.setuptools.packages.find]
include = ["dagster_orchestration*"]  # Exclude clients/ and shared/
```

```yaml
# workspace.yaml (local dev)
load_from:
  - python_module: dagster_orchestration.definitions
```

```yaml
# dagster_cloud.yaml
locations:
  - location_name: dbt-orchestration-hub
    code_source:
      module_name: dagster_orchestration.definitions
    build:
      directory: .
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Put dagster code inside dbt project | Separate `dagster_orchestration/` package |
| Use global `~/.dbt/profiles.yml` | Keep profiles.yml per client |
| Hardcode credentials in profiles.yml | Use `env_var()` with dummy defaults |
| Omit `[tool.dagster]` in pyproject.toml | Required for Dagster Cloud |
| Omit `[tool.setuptools.packages.find]` | Needed when multiple top-level dirs exist |

## See Also

- [dbt-integration](../patterns/dbt-integration.md)
- [dagster-cloud](../concepts/dagster-cloud.md)
- [definitions](../concepts/definitions.md)
