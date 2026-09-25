# 0002 — dbt-core on ECS Fargate Spot, replacing dbt Cloud and MWAA

**Status:** accepted; running since 2026-03-20. MWAA deleted 2026-03-23.

## Context

dbt ran on dbt Cloud (Starter, one seat). An MWAA environment, `mwaa-airflow-env` (mw1.large), held
two DAGs: `DBT_PROCESS_SIMPLIFIED`, paused since 2025-10, and `LISTRAK_INCREMENTAL_V2`, which loaded
Listrak marketing data into Redshift.

## Decision

Run `dbt build` as an ECS Fargate Spot task on a schedule, from `ecs/Dockerfile`, deployed by
`.github/workflows/deploy-ecs.yml` on every push to `main` that touches `ammodepot/**` or `ecs/**`.
Delete MWAA, and drop the Listrak load, whose data no longer fed reporting.

## Why

dbt Cloud at a 10-minute cadence would have cost ~$4,227 a month (427 K model runs), ~$663 even
hourly; the same build on Fargate Spot costs ~$3.70 a month. With the Airbyte host downsize and MWAA,
~$847 a month realized.

## Consequences

- The schedule, the entrypoint's order, and the race between CI and a local push: `../../ecs/AGENTS.md`.
- Deploy is automatic because it was once forgotten: after nine commits, ECS ran a stale image for
  hours.
- If Listrak is needed again, it is an ECS task or a Lambda — not MWAA.
- `archive/mwaa/` was removed from the repository and its history on 2026-03-25 because its DAGs
  embedded credentials. Do not restore those files.
