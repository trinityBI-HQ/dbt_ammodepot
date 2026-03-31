---
paths:
  - "**/models/**/*.sql"
  - "**/models/**/*.yml"
  - "**/dbt_project.yml"
  - "**/macros/**/*.sql"
---

# dbt Conventions

> **Full reference**: `.claude/docs/05_DBT_DATA_PRACTICE_STANDARDS.md`

## Model Naming (Enforced)

- Bronze: `bronze_{source}__{entity}` in `models/bronze/{source}/`
- Silver: `silver_{domain}__{entity}` in `models/silver/{domain}/`
- Gold: `{entity}` (no prefix) in `models/gold/{domain}/`
- Intermediate: `int_{entity}_{verb}` in `models/intermediate/{domain}/`

## Layer Rules

- **Bronze**: `source()` calls ONLY here. Materialized as `view`. No joins. 1:1 with source table.
- **Silver**: Business logic, joins, dedup, aggregation. Materialized as `table` or `incremental`.
- **Gold**: Consumption-ready, denormalized. Materialized as `table` or `incremental`.
- **Intermediate**: Never exposed to consumers. Materialized as `ephemeral` or `view`.

## Column Naming

- All columns: snake_case, all lowercase
- PKs: `{entity}_id`
- FKs: `{referenced_entity}_id`
- Booleans: `is_{state}` or `has_{thing}`
- Timestamps: `{event}_at` (always UTC)
- Dates: `{event}_date`

## Configuration

- Directory-level defaults in `dbt_project.yml`
- Per-model `config()` block ONLY when overriding defaults
- No hardcoded business values — use `var()` with defaults

## Testing Minimums

- Every model: `unique` + `not_null` on PK
- Every FK: `relationships` test
- Every Gold model: at least 1 business logic assertion
- Gold severity: `error`. Silver PKs: `error`. Bronze: `warn`.

## Documentation Minimums

- Every model: `description` in schema YAML
- Every Gold column: `description`
- Sources: `_{source}__sources.yml` alongside Bronze models
- Models: `_{domain}__models.yml` alongside models

## SQL Standards

See `.claude/rules/sql-standards.md` for formatting (no SELECT *, 80-char lines, CTEs, joins).
