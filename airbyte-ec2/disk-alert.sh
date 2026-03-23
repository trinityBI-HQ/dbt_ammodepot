#!/bin/bash
set -euo pipefail

# Disk usage alert — run every 6 hours via cron
# Logs warning if disk exceeds threshold
#
# Environment:
#   DISK_THRESHOLD — Override default 70% threshold (optional)

# --- Configuration ---
THRESHOLD="${DISK_THRESHOLD:-70}"
CONTAINER="airbyte-abctl-control-plane"
LOG_PREFIX="[disk-alert]"

# --- Helpers ---
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $*"; }

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

log "Top disk consumers:"
log "$TOP_USAGE"
log "Top DB tables:"
log "$DB_SIZES"
log "Run cleanup: sudo /opt/scripts/airbyte-cleanup.sh"
