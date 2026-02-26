# Best Practices

> **Purpose**: Official dbt best practices compilation from docs.getdbt.com
> **Source**: https://docs.getdbt.com/best-practices
> **MCP Validated**: 2026-02-19

## Core Philosophy

Transform data from **source-conformed** (shaped by external systems) to **business-conformed** (shaped by business needs). Apply DRY: logic should exist in only one place.

## DAG Design

- **Narrow the DAG, widen the tables**: many inputs to a model is fine; many outputs signals a problem
- Don't develop linearly through DAG order — mock output first, then stage inputs
- Recommended flow: mock in spreadsheet → write output SQL → identify deps → stage → build marts → refactor

## Staging Layer Rules

### Do

- One staging model per source table (1:1 mapping)
- Rename columns to business terminology
- Type cast to correct data types
- Basic computations (cents to dollars)
- Categorize with CASE WHEN
- Materialize as **views**
- Organize folders by **source system** (`staging/stripe/`, `staging/shopify/`)
- Use `source()` macro only in staging — nowhere else

### Don't

- No joins in staging (keeps models as atomic building blocks)
- No aggregations (would change grain, losing access to source rows)
- Don't organize by loader (Fivetran, Stitch) or business group

### Base Models

Use a `base/` subfolder when staging requires joins:
- Joining delete/soft-delete tables to main entity
- Unioning identical schemas from multiple regions/stores

## Intermediate Layer Rules

- Purpose-built transformations that prepare data for marts
- Materialize as **ephemeral** (default) or views in restricted schema
- Organize by **business function** (not source system)
- Name with verbs: `int_payments_pivoted_to_orders`, `int_orders_aggregated_to_customers`
- Never expose in main production schema
- Use for: structural simplification (reduce 10+ joins), re-graining, isolating complexity

## Marts Layer Rules

- Wide, denormalized business entities at defined grain
- Organize by **department** (finance, marketing) — skip subfolders if <10 marts
- Use plain entity names: `customers`, `orders` (no prefix)
- Start as **views**, escalate to **tables**, then **incremental**
- Don't create department-prefixed variations (`finance_orders` is an anti-pattern)
- Limit to 4-5 joins; use intermediate models beyond that
- With Semantic Layer: keep normalized; without: denormalize heavily

## Materialization Escalation

```text
1. Start with VIEW (always current, no storage)
     ↓ query too slow for end users
2. Switch to TABLE (fast queries, rebuild each run)
     ↓ build time too long in dbt jobs
3. Switch to INCREMENTAL (layer data as it arrives)
```

## Testing Best Practices

### Every Model Should Have

- `unique` + `not_null` on primary key
- `not_null` on critical foreign keys
- `relationships` test on foreign keys (use `severity: warn` if orphans expected)
- `accepted_values` on status/category columns

### Custom Generic Tests

- Place in `tests/generic/` (preferred) or `macros/`
- Test passes when query returns zero rows
- Use `config(severity='warn')` for defaults
- Check `dbt-utils` and `dbt-expectations` packages before writing from scratch
- Override built-in tests by creating a test block with the same name

### Testing Layers

| Layer | Test Focus |
|-------|-----------|
| Sources | Schema validation, freshness |
| Staging | Uniqueness, not null, type correctness |
| Marts | Business logic, referential integrity, ranges |

## CI/CD Best Practices

### Slim CI with Incremental Models

Problem: Modified incremental models don't exist in PR schema → full refresh in CI.

Solution (dbt 1.6+, requires zero-copy clone support):
```bash
# Step 1: Clone existing incremental models into PR schema
dbt clone --select state:modified+,config.materialized:incremental,state:old

# Step 2: Build modified models (runs incrementally, not full refresh)
dbt build --select state:modified+
```

`state:old` ensures only pre-existing models are cloned; new ones still full-refresh.

## Performance Patterns

- Aggregate early on smaller datasets before joins
- Push transformations upstream (do once in staging, reference everywhere)
- Select only needed columns in import CTEs
- Apply WHERE filters in import CTEs to reduce scan size
- Prefer `union all` over `union` (skips deduplication overhead)

## Documentation Practices

- Use `_[source]__sources.yml` alongside staging models
- Use `_[source]__models.yml` for model-level documentation
- Use `_[source]__docs.md` for long-form descriptions
- Document custom tests with `test_` prefix in schema.yml
- Include descriptions on every column exposed to end users

## Anti-Patterns

| Anti-Pattern | Why It's Bad | Fix |
|-------------|-------------|-----|
| Joins in staging | Duplicated logic, unclear lineage | Move to intermediate |
| Aggregations in staging | Changes grain, loses source rows | Move to intermediate |
| `source()` outside staging | Multiple entry points for raw data | Only in staging models |
| `fct_`/`dim_` everywhere | Over-classification in early layers | Only in marts if needed |
| Department-prefixed marts | Fragmented single source of truth | One mart per entity |
| 10+ joins in one model | Unreadable, hard to debug | Break into intermediate |
| Developing linearly | Messy models, unclear purpose | Mock output first |

## See Also

- [project-structure.md](project-structure.md)
- [style-guide.md](style-guide.md)
- [testing-strategy.md](testing-strategy.md)
- [../concepts/materializations.md](../concepts/materializations.md)
