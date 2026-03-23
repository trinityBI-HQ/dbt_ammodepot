#!/bin/bash
set -euo pipefail

# Airbyte monthly cleanup — run on 1st of each month at 3am UTC
# Retains 30 days of history, logs to /var/log/airbyte-cleanup.log
#
# Usage:
#   ./airbyte-cleanup.sh              # Normal run
#   ./airbyte-cleanup.sh --dry-run    # Preview only (no deletions)
#
# Environment:
#   RETENTION_DAYS — Override default 30-day retention (optional)

# --- Configuration ---
DAYS="${RETENTION_DAYS:-30}"
CONTAINER="airbyte-abctl-control-plane"
NAMESPACE="airbyte-abctl"
DB_USER="airbyte"
DB_NAME="db-airbyte"
LOG_PREFIX="[airbyte-cleanup]"
DRY_RUN=false

# --- Parse arguments ---
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# --- Helpers ---
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $*"; }

run_psql() {
    local sql="$1"
    docker exec "$CONTAINER" kubectl exec -n "$NAMESPACE" airbyte-db-0 -- \
        psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "$sql"
}

get_disk_pct() {
    docker exec "$CONTAINER" df / --output=pcent | tail -1 | tr -dc '0-9'
}

# --- Pre-flight checks ---
log "Starting cleanup (retain ${DAYS} days, dry_run=${DRY_RUN})"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    log "ERROR: Container '$CONTAINER' is not running"
    exit 1
fi

BEFORE=$(get_disk_pct)
log "Disk usage before: ${BEFORE}%"

# --- Step 1: Count what will be cleaned (always runs) ---
log "--- Analyzing records to clean ---"

MINIO_LOG_PATH="/var/local-path-provisioner/airbyte-minio-pv/airbyte-storage/job-logging/workspace"

MINIO_COUNT=$(docker exec "$CONTAINER" find "$MINIO_LOG_PATH" \
    -mindepth 1 -maxdepth 1 -mtime +"${DAYS}" 2>/dev/null | wc -l || echo 0)
log "Minio job log dirs older than ${DAYS} days: $MINIO_COUNT"

ATTEMPTS_COUNT=$(run_psql "SELECT count(*) FROM attempts WHERE created_at < NOW() - INTERVAL '${DAYS} days';")
JOBS_COUNT=$(run_psql "SELECT count(*) FROM jobs WHERE created_at < NOW() - INTERVAL '${DAYS} days';")
log "DB records to delete: attempts=$ATTEMPTS_COUNT, jobs=$JOBS_COUNT"

if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY RUN — no changes made. Exiting."
    exit 0
fi

# --- Step 2: Clean Minio job logs ---
log "--- Cleaning Minio job logs older than ${DAYS} days ---"
docker exec "$CONTAINER" find "$MINIO_LOG_PATH" \
    -mindepth 1 -maxdepth 1 -mtime +"${DAYS}" -exec rm -rf {} + 2>/dev/null || true
log "Minio cleanup complete"

# --- Step 3: Clean dependent DB tables (FK references to attempts) ---
log "--- Cleaning dependent database tables ---"
for table in stream_attempt_metadata stream_stats sync_stats; do
    DELETED=$(run_psql \
        "WITH deleted AS (
            DELETE FROM ${table}
            WHERE attempt_id IN (
                SELECT id FROM attempts WHERE created_at < NOW() - INTERVAL '${DAYS} days'
            )
            RETURNING 1
        ) SELECT count(*) FROM deleted;")
    log "  ${table}: deleted $DELETED rows"
done

# --- Step 4: Clean attempts table ---
log "--- Cleaning attempts table ---"
DELETED=$(run_psql \
    "WITH deleted AS (
        DELETE FROM attempts WHERE created_at < NOW() - INTERVAL '${DAYS} days'
        RETURNING 1
    ) SELECT count(*) FROM deleted;")
log "  attempts: deleted $DELETED rows"

# --- Step 5: Clean jobs table ---
log "--- Cleaning jobs table ---"
DELETED=$(run_psql \
    "WITH deleted AS (
        DELETE FROM jobs WHERE created_at < NOW() - INTERVAL '${DAYS} days'
        RETURNING 1
    ) SELECT count(*) FROM deleted;")
log "  jobs: deleted $DELETED rows"

# --- Step 6: VACUUM (regular, not FULL — less disruptive for scheduled runs) ---
log "--- Running VACUUM ---"
for table in attempts jobs stream_attempt_metadata stream_stats sync_stats; do
    run_psql "VACUUM ${table};" > /dev/null 2>&1
    log "  VACUUM $table complete"
done

# --- Report results ---
AFTER=$(get_disk_pct)
log "Disk usage after: ${AFTER}%"
log "Cleanup complete. Disk: ${BEFORE}% -> ${AFTER}%"
log "Deleted: ${ATTEMPTS_COUNT} attempts, ${JOBS_COUNT} jobs, ${MINIO_COUNT} log dirs"
log "Done."
