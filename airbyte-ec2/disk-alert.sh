#!/bin/bash
set -euo pipefail

# Disk usage alert — run every 6 hours via systemd timer (disk-alert.timer)
# Logs warning AND publishes to SNS if disk exceeds threshold.
#
# Environment:
#   DISK_THRESHOLD — Override default 70% threshold (optional)
#   SNS_TOPIC_ARN  — SNS topic to publish breaches to. If unset, the script only
#                    logs locally. On 2026-07-15 that silence let the root disk
#                    reach 100% and stall ingestion for ~4.5h: the check was
#                    correct, but nothing ever read /var/log/disk-alert.log.

# --- Configuration ---
THRESHOLD="${DISK_THRESHOLD:-70}"
SNS_TOPIC_ARN="${SNS_TOPIC_ARN:-}"
CONTAINER="airbyte-abctl-control-plane"
LOG_PREFIX="[disk-alert]"

# --- Helpers ---
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $*"; }

# Alerting must never take the host down: a failed publish is logged, not fatal
# (this script runs under `set -euo pipefail`).
publish_sns() {
    local subject="$1" body="$2"
    if [[ -z "$SNS_TOPIC_ARN" ]]; then
        log "WARNING: SNS_TOPIC_ARN unset — alert stays local and nobody is paged"
        return 0
    fi
    if aws sns publish --topic-arn "$SNS_TOPIC_ARN" \
        --subject "$subject" --message "$body" >/dev/null 2>&1; then
        log "SNS alert published to $SNS_TOPIC_ARN"
    else
        log "ERROR: SNS publish failed (check sns:Publish on the instance role)"
    fi
}

# --- Check disk ---
DISK_PCT=$(df / --output=pcent | tail -1 | tr -dc '0-9')

if [[ "$DISK_PCT" -lt "$THRESHOLD" ]]; then
    log "Disk at ${DISK_PCT}% (threshold: ${THRESHOLD}%) — OK"
    exit 0
fi

log "WARNING: Disk at ${DISK_PCT}% (threshold: ${THRESHOLD}%)"

# Get top space consumers for context
TOP_USAGE=$(docker exec "$CONTAINER" du -d 1 -h /var/local-path-provisioner/ 2>/dev/null \
    | sort -rh | head -5 || echo "Could not read container disk usage")

# Get DB table sizes
DB_SIZES=$(docker exec "$CONTAINER" kubectl exec -n airbyte-abctl airbyte-db-0 -- \
    psql -U airbyte -d db-airbyte -t -A -c \
    "SELECT relname || ': ' || pg_size_pretty(pg_total_relation_size(oid))
     FROM pg_class WHERE relkind='r'
     ORDER BY pg_total_relation_size(oid) DESC LIMIT 5;" 2>/dev/null || echo "Could not read DB sizes")

# --- Decide whether VACUUM FULL is even applicable ---
# This block exists because on 2026-09-17 this alert was recommending
# `--vacuum-full` on a table that was 46 GB of LIVE data and 6% bloat, with only
# 13 GB free. VACUUM FULL rewrites the table into NEW files before dropping the
# old ones, so it needs free space >= the table size. Running it there would have
# reclaimed ~3 GB at best and filled the disk to 100% at worst — which is the exact
# failure mode of the 2026-07-15 outage this alert was written to prevent.
# Never recommend it unconditionally: compute it.
AVAIL_KB=$(df / --output=avail | tail -1 | tr -dc '0-9')
BIGGEST=$(docker exec "$CONTAINER" kubectl exec -n airbyte-abctl airbyte-db-0 -- \
    psql -U airbyte -d db-airbyte -t -A -F'|' -c \
    "SELECT relname, pg_total_relation_size(oid)/1024
     FROM pg_class WHERE relkind='r'
     ORDER BY pg_total_relation_size(oid) DESC LIMIT 1;" 2>/dev/null || echo "")

if [[ -n "$BIGGEST" ]]; then
    BIG_TBL="${BIGGEST%%|*}"
    BIG_KB="${BIGGEST##*|}"
    if [[ "$BIG_KB" =~ ^[0-9]+$ ]] && [[ "$AVAIL_KB" -gt "$BIG_KB" ]]; then
        VACUUM_ADVICE="  sudo /opt/scripts/airbyte-cleanup.sh --vacuum-full  # reclaim disk (LOCKS Airbyte)
  Space check PASSES: ${BIG_TBL} is $((BIG_KB/1024/1024)) GB, $((AVAIL_KB/1024/1024)) GB free — the rewrite fits.
  But fitting is not the same as being worth it. VACUUM FULL only reclaims DEAD
  space, and it holds an ACCESS EXCLUSIVE lock for the whole rewrite. Measure the
  live fraction before you take that lock (this scans the table, run it off-peak):
    SELECT pg_size_pretty(sum(pg_column_size(t.*))::bigint) FROM ${BIG_TBL} t;
  If that is close to $((BIG_KB/1024/1024)) GB, the table is live data, not bloat:
  cut RETENTION_DAYS in airbyte-cleanup.service or grow the volume instead."
    else
        VACUUM_ADVICE="  DO NOT run --vacuum-full: ${BIG_TBL} is $((BIG_KB/1024/1024)) GB but only
  $((AVAIL_KB/1024/1024)) GB is free. VACUUM FULL rewrites the table before freeing the
  old files, so it needs free space >= table size. It would fail mid-rewrite and
  could fill the disk to 100%.
  If the prune is running and the disk is still full, the data is LIVE, not bloat —
  the fix is retention (RETENTION_DAYS in airbyte-cleanup.service) or a bigger volume,
  not more vacuuming. Verify with:
    SELECT pg_size_pretty(sum(pg_column_size(t.*))::bigint) FROM ${BIG_TBL} t;"
    fi
else
    VACUUM_ADVICE="  Could not size the largest table — check free space before any --vacuum-full."
fi

log "Top disk consumers:"
log "$TOP_USAGE"
log "Top DB tables:"
log "$DB_SIZES"
log "Run cleanup: sudo /opt/scripts/airbyte-cleanup.sh"
log "VACUUM FULL advice:"
log "$VACUUM_ADVICE"

# --- Page a human ---
# At 70% on a disk that fills over weeks this buys days of lead time, which is the
# difference between a scheduled chore and a 4-hour outage.
publish_sns "[Airbyte DISK] ${DISK_PCT}% used on $(hostname)" \
"Airbyte EC2 root disk is at ${DISK_PCT}% (threshold ${THRESHOLD}%).

Host: $(hostname) ($(hostname -i 2>/dev/null || echo 'ip unknown'))
Filesystem:
$(df -h / | tail -1)

Top disk consumers:
${TOP_USAGE}

Top DB tables:
${DB_SIZES}

Remediation:
  sudo /opt/scripts/airbyte-cleanup.sh --dry-run   # preview
  sudo /opt/scripts/airbyte-cleanup.sh             # prune + VACUUM
${VACUUM_ADVICE}

Runbook: docs/AIRBYTE_INCIDENT_RUNBOOK.md
Note: at 100% the SSM agent cannot spawn a shell (commands fail instantly with
no output). If that happens, reboot via the EC2 API to regain access."
