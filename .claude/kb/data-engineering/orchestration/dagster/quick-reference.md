# Dagster Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Core Decorators

| Decorator | Purpose | Returns |
|-----------|---------|---------|
| `@asset` | Define a software-defined asset | `AssetsDefinition` |
| `@multi_asset` | Define multiple assets from one function | `AssetsDefinition` |
| `@op` | Define computational unit (legacy pattern) | `OpDefinition` |
| `@job` | Define executable job from ops/graphs | `JobDefinition` |
| `@graph` | Define DAG of ops | `GraphDefinition` |
| `@schedule` | Define time-based trigger | `ScheduleDefinition` |
| `@sensor` | Define event-based trigger | `SensorDefinition` |
| `@resource` | Define external service connection | `ResourceDefinition` |

## Asset Configuration

| Config Option | Values | Description |
|---------------|--------|-------------|
| `key` | `str` or `AssetKey` | Unique identifier for asset |
| `group_name` | `str` | Logical grouping in UI |
| `io_manager_key` | `str` | Which IO manager to use |
| `partitions_def` | `PartitionsDefinition` | Partitioning scheme |
| `deps` | `list[AssetKey]` | External dependencies |
| `automation_condition` | `AutomationCondition` | Declarative automation (GA v1.9, replaces `AutoMaterializePolicy`) |
| `check_specs` | `list[AssetCheckSpec]` | Asset checks with optional automation conditions |

## Partition Types

| Type | Use Case | Example |
|------|----------|---------|
| `DailyPartitionsDefinition` | Time-based daily | `DailyPartitionsDefinition(start_date="2024-01-01")` |
| `HourlyPartitionsDefinition` | Time-based hourly | Processing streaming data |
| `MonthlyPartitionsDefinition` | Time-based monthly | Monthly reports |
| `StaticPartitionsDefinition` | Fixed set of keys | `["us", "eu", "apac"]` |
| `DynamicPartitionsDefinition` | Runtime-determined | New customers, regions |
| `MultiPartitionsDefinition` | Multi-dimensional | Date + region combinations |

## Built-in IO Managers

| IO Manager | Storage | Package |
|------------|---------|---------|
| `FilesystemIOManager` | Local pickle files | `dagster` |
| `S3PickleIOManager` | AWS S3 | `dagster-aws` |
| `GCSPickleIOManager` | Google Cloud Storage | `dagster-gcp` |
| `BigQueryPandasIOManager` | BigQuery tables | `dagster-gcp` |
| `SnowflakePandasIOManager` | Snowflake tables | `dagster-snowflake` |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Data transformation pipeline | `@asset` with dependencies |
| Multiple outputs from one computation | `@multi_asset` |
| Orchestrate dbt models | `@dbt_assets` from `dagster-dbt` |
| Complex imperative logic | `@graph` with `@op` nodes |
| Run on schedule | `ScheduleDefinition` (job-less) or `@schedule` |
| React to external events | `@sensor` (job-less supported) |
| Auto-materialize on conditions | `AutomationCondition` on `@asset` |
| BI assets in lineage graph | `dagster-tableau`, `dagster-powerbi`, `dagster-looker` |
| Migrate from Airflow | `dagster-airlift` toolkit |
| Large dataset processing | Partitioned assets with backfills |

## Common CLI Commands

| Command | Description |
|---------|-------------|
| `dagster dev` | Start local development server |
| `dagster asset materialize` | Materialize assets |
| `dagster job execute` | Execute a job |
| `dagster-daemon run` | Start the daemon (schedules/sensors) |
| `dg scaffold` | Scaffold new components |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use `@op` for new pipelines | Use `@asset` for declarative pipelines |
| Use `AutoMaterializePolicy` | Use `AutomationCondition` (GA in v1.9) |
| Hardcode credentials | Use `EnvVar` in resources |
| Skip IO managers | Use IO managers for testability |
| Test entire jobs | Test individual assets |
| One massive definitions.py | Split by domain as project grows |

## Related Documentation

| Topic | Path |
|-------|------|
| Getting Started | `concepts/software-defined-assets.md` |
| Project Organization | `patterns/project-structure.md` |
| Full Index | `index.md` |
