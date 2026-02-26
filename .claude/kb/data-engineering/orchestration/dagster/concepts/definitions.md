# Definitions and Code Locations

> **Purpose**: Container for all project components and entry point for Dagster tools
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The `Definitions` object is the structural backbone of any Dagster project. It contains all assets, jobs, schedules, sensors, and resources that should be deployed and visible in the Dagster UI. Code locations tell Dagster where these components live and how to run them. This separation allows the webserver and daemon to interact with user code over a serialization boundary.

## The Pattern

```python
import dagster as dg
from dagster_dbt import DbtCliResource

from .assets.sales import sales_assets
from .assets.marketing import marketing_assets
from .jobs import daily_refresh_job
from .schedules import daily_schedule
from .sensors import new_file_sensor

# Single Definitions object at module top-level
defs = dg.Definitions(
    assets=[*sales_assets, *marketing_assets],
    jobs=[daily_refresh_job],
    schedules=[daily_schedule],
    sensors=[new_file_sensor],
    resources={
        "dbt": DbtCliResource(project_dir="dbt_project"),
        "warehouse": SnowflakeResource(
            account=dg.EnvVar("SNOWFLAKE_ACCOUNT"),
            user=dg.EnvVar("SNOWFLAKE_USER"),
            password=dg.EnvVar("SNOWFLAKE_PASSWORD"),
        ),
    },
)
```

## Quick Reference

| Parameter | Type | Description |
|-----------|------|-------------|
| `assets` | `list[AssetsDefinition]` | All software-defined assets |
| `jobs` | `list[JobDefinition]` | Executable jobs |
| `schedules` | `list[ScheduleDefinition]` | Time-based triggers |
| `sensors` | `list[SensorDefinition]` | Event-based triggers |
| `resources` | `dict[str, ResourceDefinition]` | Shared resources |

## Code Location Structure

```text
my_dagster_project/
├── pyproject.toml
├── src/
│   └── my_project/
│       ├── __init__.py
│       ├── definitions.py      # Definitions object here
│       └── defs/
│           ├── assets/
│           │   ├── sales.py
│           │   └── marketing.py
│           ├── jobs.py
│           ├── schedules.py
│           └── sensors.py
└── tests/
```

## Loading Code Locations

```yaml
# workspace.yaml - for multiple code locations
load_from:
  - python_module: my_project.definitions
  - python_module: another_project.definitions
```

## Merging Definitions

```python
# Combine definitions from multiple modules
from dagster import Definitions

from .sales.definitions import sales_defs
from .marketing.definitions import marketing_defs

defs = Definitions.merge(sales_defs, marketing_defs)
```

## Common Mistakes

### Wrong

```python
# Anti-pattern: Multiple Definitions objects
defs1 = Definitions(assets=[asset_a])
defs2 = Definitions(assets=[asset_b])  # Not loaded!
```

### Correct

```python
# Correct: Single Definitions object with all components
defs = Definitions(
    assets=[asset_a, asset_b],
)
```

## Environment-Specific Configuration

```python
import os
import dagster as dg

# Different resources per environment
if os.getenv("DAGSTER_ENV") == "production":
    warehouse = ProductionSnowflakeResource()
else:
    warehouse = LocalDuckDBResource()

defs = dg.Definitions(
    assets=all_assets,
    resources={"warehouse": warehouse},
)
```

## Related

- [software-defined-assets](../concepts/software-defined-assets.md)
- [resources](../concepts/resources.md)
- [project-structure](../patterns/project-structure.md)
