#!/bin/bash
set -euo pipefail

# Deploy Airbyte maintenance scripts to EC2
#
# Usage (run on the EC2 instance, from this directory):
#   sudo ./deploy.sh
#
# What this does:
#   - Copies airbyte-cleanup.sh and disk-alert.sh to /opt/scripts/
#   - Installs + enables systemd timers (weekly cleanup + 6-hourly disk alert)
#   - Verifies the timers are actually armed
#
# Why systemd timers and not cron:
#   AL2023 does not ship cronie. The previous version of this script wired the
#   jobs with `crontab -`, which does not exist on this AMI — so `set -e` killed
#   the install before anything was scheduled. The scripts sat at /opt/ unwired
#   and NEVER RAN, which is how the root disk reached 100% on 2026-07-15.
#   systemd is present by default, so there is nothing to install.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/opt/scripts"
SYSTEMD_DIR="/etc/systemd/system"
UNITS=(airbyte-cleanup.service airbyte-cleanup.timer disk-alert.service disk-alert.timer)

echo "=== Airbyte Maintenance Installer ==="
echo ""

# --- Must run as root ---
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo ./deploy.sh)"
    exit 1
fi

# --- Pre-flight: systemd must be the init system ---
if ! command -v systemctl >/dev/null 2>&1; then
    echo "ERROR: systemctl not found — cannot schedule maintenance on this host."
    exit 1
fi

# --- Step 1: Install scripts ---
echo "[1/4] Installing scripts to ${INSTALL_DIR}/"
mkdir -p "$INSTALL_DIR"
install -m 0755 "$SCRIPT_DIR/airbyte-cleanup.sh" "$INSTALL_DIR/airbyte-cleanup.sh"
install -m 0755 "$SCRIPT_DIR/disk-alert.sh" "$INSTALL_DIR/disk-alert.sh"
echo "  Done: airbyte-cleanup.sh"
echo "  Done: disk-alert.sh"

# Older deploys copied these bare into /opt/. Remove them so there is exactly one
# copy on the box and no ambiguity about which one is scheduled.
for stale in /opt/airbyte-cleanup.sh /opt/disk-alert.sh; do
    [[ -f "$stale" ]] && { rm -f "$stale"; echo "  Removed stale copy: $stale"; }
done

# --- Step 2: Install systemd units ---
echo ""
echo "[2/4] Installing systemd units to ${SYSTEMD_DIR}/"
for unit in "${UNITS[@]}"; do
    install -m 0644 "$SCRIPT_DIR/systemd/$unit" "$SYSTEMD_DIR/$unit"
    echo "  Done: $unit"
done
systemctl daemon-reload

# --- Step 3: Enable timers (idempotent) ---
echo ""
echo "[3/4] Enabling timers"
systemctl enable --now airbyte-cleanup.timer
systemctl enable --now disk-alert.timer
echo "  Done: airbyte-cleanup.timer (weekly, Sun 03:00 UTC)"
echo "  Done: disk-alert.timer (every 6h)"

# --- Step 4: Verify the timers are ACTUALLY armed ---
# The old script printed "Done" without ever confirming the schedule existed.
# Fail loudly here instead of discovering it months later via an outage.
echo ""
echo "[4/4] Verifying"
FAILED=0
for timer in airbyte-cleanup.timer disk-alert.timer; do
    if systemctl is-active --quiet "$timer" && systemctl is-enabled --quiet "$timer"; then
        NEXT=$(systemctl show "$timer" -p NextElapseUSecRealtime --value)
        echo "  OK: $timer active+enabled (next: ${NEXT:-unknown})"
    else
        echo "  FAIL: $timer is NOT armed"
        FAILED=1
    fi
done

if [[ $FAILED -ne 0 ]]; then
    echo ""
    echo "ERROR: one or more timers failed to arm — maintenance is NOT scheduled."
    exit 1
fi

echo ""
systemctl list-timers airbyte-cleanup.timer disk-alert.timer --no-pager 2>/dev/null || true

# --- Dry run test ---
echo ""
echo "=== Running dry-run test ==="
"$INSTALL_DIR/airbyte-cleanup.sh" --dry-run || {
    echo ""
    echo "Warning: Dry run failed — the Docker container may not be running."
    echo "  This is OK if you're deploying before Airbyte is started."
}

echo ""
echo "=== Installation complete ==="
echo ""
echo "IMPORTANT: disk-alert only pages if the instance role can publish to SNS."
echo "  The topic is set in systemd/disk-alert.service (SNS_TOPIC_ARN)."
echo "  The instance role (EC2_SSM_Access) needs sns:Publish on that topic."
echo "  Verify with: sudo systemctl start disk-alert.service && tail /var/log/disk-alert.log"
echo ""
echo "Next steps:"
echo "  1. Preview cleanup:  sudo ${INSTALL_DIR}/airbyte-cleanup.sh --dry-run"
echo "  2. Run cleanup:      sudo ${INSTALL_DIR}/airbyte-cleanup.sh"
echo "  3. Reclaim disk:     sudo ${INSTALL_DIR}/airbyte-cleanup.sh --vacuum-full  # LOCKS Airbyte"
echo "  4. Check timers:     systemctl list-timers 'airbyte*' 'disk*'"
echo "  5. Check logs:       tail -f /var/log/airbyte-cleanup.log /var/log/disk-alert.log"
