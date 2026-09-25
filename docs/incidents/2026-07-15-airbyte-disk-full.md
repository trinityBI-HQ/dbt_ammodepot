# 2026-07-15 — Airbyte stalled 4.5 hours: the root disk was full

The Airbyte host's root disk reached 100% (20 MB free of 100 GB). From 17:15 UTC `workload-launcher`
failed its probes, replication pods could not start, and **jobs reported `succeeded` with 0 bytes and
0 rows** — the Airbyte UI stayed green; only the freshness monitor saw it. It was not the OOM cascade
of early July: the node stayed `Ready` and there was no kernel OOM.

## Why

The maintenance jobs had **never run, in 99 days**. `deploy.sh` installed them with `crontab -`;
AL2023 ships no cron, so under `set -e` the install died before scheduling anything. Nothing paged
either: `disk-alert.sh` wrote only to a local log. `airbyte-ec2/` is the one directory no workflow
deploys, so git said "deployed" while the host never ran it.

## Recovery

A reboot through the EC2 API — SSM was failing, and an instant `Failed` with empty output is the
full-disk signature. Then: delete an orphaned 7.6 GB backup tarball left by the early-July recovery,
and `docker image prune -af` (7.27 GB). 100% → 86%; syncs resumed within minutes.

## What changed

- **PR #30:** maintenance as **systemd timers**, which fired on their own for the first time;
  `disk-alert.sh` publishes to SNS `airbyte-auto-remediate-events` (policy `AirbyteDiskAlertSNSPublish`
  on role `EC2_SSM_Access`); the job-log path corrected to `airbyte-local-pv/job-logging` (19,407
  directories, ~12 GB pruned); `--vacuum-full` reclaimed the pgdata ratchet. Disk 100% → 53%.
- Later: alert threshold 85% (PR #38); the disk sized by retention (PR #41).

## What it taught

- **A `succeeded` job with zero bytes is a failure Airbyte will not show you.**
- **Verify recovery from Airbyte's `bytesSynced` and S3 object times, not freshness.** Snowflake sees
  new data only after the next build's Iceberg refresh, a cycle behind S3. `aws s3 ls` prints local
  time.
- **Remediation through SSM dies with the host.** The Lambda's commands failed, it opened its breaker
  and logged `skipped_breaker_open`; a reboot through the EC2 API was the only lever left.
- **Edge-triggered alerts fire once.** The freshness alerts fired at 17:50 and 18:35 UTC, then stayed
  silent through three more hours of outage.
