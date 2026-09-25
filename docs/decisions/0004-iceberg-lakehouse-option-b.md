# 0004 — Snowflake reads Airbyte's Iceberg in place (Option B)

**Status:** accepted; cut over 2026-04-07 ~17:00 UTC. Supersedes
[0003](0003-duckdb-lakehouse-poc.md).

## Context

Airbyte loaded Fishbowl and Magento straight into Snowflake, and its user `SVC_AIRBYTE` burned 678
credits a month — 74% of all compute.

## Decision

Airbyte writes CDC as Iceberg to S3, cataloged in Glue; Snowflake reads it in place as 55 unmanaged
Iceberg tables in `AD_ANALYTICS.LAKEHOUSE_LANDING`; the same dbt project builds Silver and Gold from
them. How it works: `../architecture/warehouse.md`.

## Alternatives

- **A full DuckDB lakehouse** ([0003](0003-duckdb-lakehouse-poc.md)) — dbt-duckdb transforming on S3,
  Gold copied into Snowflake. Validated, and ~$4,152 a year cheaper still, but it added four helper
  scripts, Iceberg write bugs, OOMs and 3–4-hour initial loads. Option B kept 85% of the savings at
  near-zero complexity.
- The status quo: ingestion compute inside Snowflake.

## Consequences

- `SVC_AIRBYTE` fell from ~22.6 credits an hour to ~0 within minutes: ~$2,034 a month, verified
  2026-04-07 18:25 UTC from its credit consumption.
- **The tables are unmanaged**, so every build refreshes them first: `ecs/refresh_iceberg.py`, 8
  threads (~55 s warm, ~80 s cold), fail-fast because a build from a stale catalog ships wrong numbers.
  It replaced a dbt `on-run-start` macro that ran serially (87 s warm, 319 s cold); the macro is gone.
- Iceberg changes types — `_airbyte_extracted_at` as epoch milliseconds, business timestamps as
  `TIMESTAMP_LTZ`: the traps are in `../../ammodepot/AGENTS.md`.
- Iceberg is append-only: rows with a NULL primary key, which the old MERGE dropped, now arrive.
  Silver's `QUALIFY ROW_NUMBER()` and a NULL-PK guard handle them.
- Hand-built views in `AD_AIRBYTE` that Power BI read went stale at the cutover —
  `../architecture/warehouse.md`.
- The legacy Snowflake connections were left inactive rather than deleted, and `AD_AIRBYTE` was kept
  for comparison (~56.8 GB active + 247 GB fail-safe); as of 2026-04-08 dropping it was undecided.
