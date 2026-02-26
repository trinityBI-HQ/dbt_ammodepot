# dbt-core Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Core Commands

| Command | Purpose | Common Flags |
|---------|---------|--------------|
| `dbt run` | Execute models | `--select`, `--exclude`, `--full-refresh` |
| `dbt test` | Run data tests | `--select`, `--store-failures` |
| `dbt build` | Run + test in DAG order | `--select`, `--full-refresh` |
| `dbt compile` | Generate compiled SQL | `--select` |
| `dbt docs generate` | Build documentation | |
| `dbt snapshot` | Run snapshots | `--select` |
| `dbt seed` | Load CSV seed files | `--select`, `--full-refresh` |
| `dbt run --sample` | Time-based sample mode (v1.10+) | `--sample` |

## Materializations

| Type | Use Case | Rebuild Behavior |
|------|----------|------------------|
| `view` | Small, simple models | Always current |
| `table` | Frequently queried models | Full rebuild each run |
| `incremental` | Large fact tables | Append/merge new rows |
| `microbatch` | Time-series incremental (v1.9+) | Process in time batches |
| `ephemeral` | CTEs, no warehouse object | Inlined into parent |

## Jinja Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `ref('model')` | Reference another model | `{{ ref('stg_orders') }}` |
| `source('src', 'tbl')` | Reference raw source | `{{ source('raw', 'orders') }}` |
| `config(...)` | Set model configuration | `{{ config(materialized='table') }}` |
| `var('name')` | Access project variable | `{{ var('start_date') }}` |
| `env_var('NAME')` | Access environment variable | `{{ env_var('DBT_TARGET') }}` |

## Generic Tests

| Test | Purpose | Example |
|------|---------|---------|
| `unique` | No duplicate values | Primary keys |
| `not_null` | No NULL values | Required fields |
| `accepted_values` | Value in allowed list | Status columns |
| `relationships` | Referential integrity | Foreign keys |
| `unit` (v1.8+) | Test model logic with mocks | Business calculations |

## Selector Syntax

| Selector | Description |
|----------|-------------|
| `model_name` | Single model |
| `+model_name` | Model and all upstream |
| `model_name+` | Model and all downstream |
| `@model_name` | Model, upstream, and downstream |
| `tag:daily` | All models with tag |
| `source:raw+` | Source and downstream models |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Time-series events > 1M rows | `microbatch` incremental strategy |
| Fact table > 1M rows | `incremental` materialization |
| Dimension table < 100K rows | `table` materialization |
| Lightweight transformation | `view` materialization |
| Reusable CTE logic | `ephemeral` or separate model |
| Track historical changes | `snapshot` |
| Validate primary key | `unique` + `not_null` tests |

## Common Pitfalls

| Do Not | Do Instead |
|--------|------------|
| Hardcode table names | Use `ref()` or `source()` |
| Skip tests on PKs | Always test `unique` + `not_null` |
| Use `*` in production | Explicitly list columns |
| One giant model | Break into staging/intermediate/marts |
| Ignore incremental logic | Test with `--full-refresh` |
| Pin exact dbt versions | Use Release Tracks (Latest, Compatible, Extended) |

## Related Documentation

| Topic | Path |
|-------|------|
| Models & DAG | `concepts/models.md` |
| Incremental Strategy | `patterns/incremental-models.md` |
| Full Index | `index.md` |
