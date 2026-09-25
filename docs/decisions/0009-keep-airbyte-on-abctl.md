---
paths: ["airbyte-ec2/**"]
---
# 0009 — Keep Airbyte on abctl for now

**Status:** accepted 2026-08-13; revisit if stability regresses.

## Context

`abctl` runs Airbyte in kind — Kubernetes in one Docker container — which is Airbyte's evaluation
installer, and it is the root of a whole class of friction here: chart values that do not
propagate, no `postgresql.resources` key, live patches a reinstall wipes, and nested cgroups that make
JVMs size themselves off the host (`../incidents/`).

## Decision

Stay on Airbyte under `abctl`. The one-hop capability that is hard to replace is **CDC → Iceberg with
deletes**, which Airbyte's `destination-s3-data-lake` does natively.

## Alternatives, as researched 2026-08-13

- **dlt** — no native MySQL binlog CDC (Postgres only; MySQL goes through Debezium).
- **AWS DMS** — does not write Iceberg: CSV or Parquet only, so AWS's own pattern is DMS → S3 → a
  Glue job → Iceberg. About $150–280 a month against ~$223 today: a migration saves nothing and costs
  weeks.
- **Airbyte under Docker Compose** — considered in 2026-05 and deferred; see
  [0008](0008-auto-remediation-architecture.md).
