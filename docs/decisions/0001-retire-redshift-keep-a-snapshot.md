# 0001 — Retire Redshift and keep one indefinite snapshot

**Status:** accepted 2026-05-01.

## Context

The warehouse moved from Amazon Redshift to Snowflake; the Redshift dbt project is archived in
`archive/projects/ammodepot/` and runs nowhere. Why Snowflake over Redshift: TBD — no source this
record was assembled from states it. The cluster, `airbyte-project-redshift-cluster` (2 × ra3.large,
~$793/month on demand, ~120 GB used), was paused around 2026-04-29.

## Decision

Delete the cluster, but first take a manual snapshot with indefinite retention: the only other backup
was a 1-day automated snapshot, which is deleted with the cluster.

- Snapshot `ammodepot-redshift-archive-2026-05-01`, us-east-1 — 122 GB (~$2.93/month), data as of
  2026-04-29, encrypted with an AWS-owned key, so no customer key has to stay alive.
- **A restore needs two resources that must outlive the cluster**: the subnet group
  `airbyte-project-redshift-subnet-group` and the IAM role `airbyte-project-redshift-s3-access`.

## Consequences

"Do we still have the Redshift data?" — yes, in that snapshot. Deletion was scheduled for May 2026;
whether it has happened: TBD.
