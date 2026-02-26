# dbt Cloud Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Materializations

| Type | Use Case | Rebuilds |
|------|----------|----------|
| `view` | Lightweight, always current | Every query |
| `table` | Heavy transforms, many downstream | Full rebuild |
| `incremental` | Large datasets, append/merge | New/changed rows |
| `microbatch` | Time-series incremental (v1.9+) | Batched by event_time |
| `ephemeral` | Reusable CTEs, no storage | Inlined to SQL |

## Common Commands

| Command | Purpose |
|---------|---------|
| `dbt run` | Execute models |
| `dbt test` | Run data and unit tests |
| `dbt build` | Run + test + snapshot in DAG order |
| `dbt seed` | Load CSV files |
| `dbt snapshot` | Capture SCD Type 2 changes |
| `dbt source freshness` | Check source data age |

## Test Types

| Type | Syntax | Use Case |
|------|--------|----------|
| Generic (built-in) | `data_tests:` in YAML | unique, not_null, relationships, accepted_values |
| Singular | `.sql` in tests/ | Custom failing-row queries |
| Unit | `unit_tests:` in YAML | Validate model logic with mock data |

## Incremental Strategies

| Strategy | Platform | Behavior |
|----------|----------|----------|
| `append` | All | Insert only, no updates |
| `merge` | BigQuery, Snowflake, Databricks | Upsert on unique_key |
| `delete+insert` | All | Delete matching, then insert |
| `microbatch` | All (v1.9+) | Time-series batches |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Need historical tracking | Snapshots |
| Large tables, append-only | Incremental (append) |
| Large tables, updates exist | Incremental (merge) |
| Complex CTE reuse | Ephemeral |
| Always-fresh dashboards | View |

## Snapshot Strategies

| Strategy | When to Use |
|----------|-------------|
| `timestamp` | Source has reliable `updated_at` column |
| `check` | No timestamp, compare column values |

## Release Tracks

| Track | Description |
|-------|-------------|
| `Latest` | Newest features, earliest access |
| `Compatible` | Stable, tested, recommended for production |
| `Extended` | Long-term support, security fixes only |
| `Latest Fusion` | Latest + dbt Fusion Engine (preview) |

## Common Pitfalls

| Do Not | Do Instead |
|--------|------------|
| Use seeds for large data | Use sources and EL tools |
| Skip `unique_key` on incremental | Always define unique_key for merge |
| Hardcode schema names | Use `{{ target.schema }}` |
| Nest complex Jinja in models | Extract to macros |
| Pin exact dbt versions | Use Release Tracks |
| Use dbt versions < 1.8 | Upgrade; 1.7 and below unsupported |

## Related Documentation

| Topic | Path |
|-------|------|
| Getting Started | `concepts/projects-environments.md` |
| Full Index | `index.md` |
