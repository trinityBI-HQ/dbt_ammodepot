---
paths: ["streamlit_cost_monitor/setup/*airbyte*.sql", "streamlit_cost_monitor/pages/6_Airbyte_Health.py", "lambda/airbyte_auto_remediate/**", "airbyte-ec2/**"]
---
# Airbyte observability

Two independent layers, on two delivery paths: switching the remediation Lambda off does not silence
the freshness alerts.

| Layer | Detects | Delivers |
|---|---|---|
| Freshness monitor (Snowflake-native) | ingestion that stopped landing in Iceberg | email via `OPS_EMAIL_NOTIFICATIONS` |
| Auto-remediation (Lambda) | the same staleness, then inspects the Airbyte job | SNS `airbyte-auto-remediate-events` — `../../lambda/airbyte_auto_remediate/` |

## The freshness monitor

Built by `streamlit_cost_monitor/setup/07_airbyte_observability.sql` (ACCOUNTADMIN, idempotent):

- `V_AIRBYTE_FRESHNESS` gives each connection's staleness from its **busiest** stream — the MAX over
  all 55 landing tables. Idle config tables (`store`, `eav_attribute_set`) are legitimately days old,
  so anything MIN-based alarms on them. A suspected per-stream "cursor rot" (2026-05-04) was checked
  against Iceberg row volumes and disproven (2026-05-14).
- Thresholds live in `AIRBYTE_FRESHNESS_THRESHOLDS`, **per connection**, and are tuned with `UPDATE` —
  no redeploy. Since 2026-07-27: `magento_s3` warn 30 / alert 45 min, `fishbowl_s3` 60 / 90.
- `ALERT_AIRBYTE_FRESHNESS_ALERT` is armed. **`ALERT_AIRBYTE_FRESHNESS_WARN` is suspended** since
  2026-07-27: it only ever fired on Fishbowl's quiet nights. The WARN status still shows on page 6;
  re-arm the email with `ALTER ALERT ... RESUME`.
- The alerts run on `ETL_WH` at `5,20,35,50` — UNIX cron, the warehouse already warm from dbt.

## Setting a threshold

**A threshold must exceed normal data age — cadence plus sync time plus the source's own quiet
periods — or edge-triggered alerts fire on every cycle.** Measured 2026-07-27, gap between extracts:
Magento p50 9 / p90 10 / p99 20 min; Fishbowl p50 10 / p90 40 / p99 60, with 27–53 minutes
between 02:00 and 09:00 UTC because nothing changes overnight in the US. A destination-freshness
monitor cannot tell "nothing changed" from "frozen", so measure by connection and by hour of day
before moving a number. A single global 25/30 pair sent ~27 emails in 26 hours.

## Email

The recipient must be a Snowflake user whose address is **verified** — `ALTER USER … SET EMAIL` only
stores it. Check `DESC USER` for `IS_EMAIL_VERIFIED = true`; until the link in Snowflake's email is
clicked, notifications are not delivered.

## What else pages, and what does not

The Lambda also watches the control plane — 3 pod restarts in 24 hours page `[Airbyte CONTROL-PLANE]`
— and every email it sends is explained in `../AIRBYTE_AUTO_REMEDIATION_RUNBOOK.md`. **Nothing watches
the Airbyte UI's availability** (gap found 2026-08-12): it answered 503 in every server restart window
without any alert firing.

Recovering a stuck sync by hand: `../AIRBYTE_INCIDENT_RUNBOOK.md`.
