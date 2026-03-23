#!/bin/bash
set -euo pipefail

# Deploy Airbyte maintenance scripts to EC2
#
# Usage (run on the EC2 instance):
#   sudo ./deploy.sh
#
# What this does:
#   - Copies airbyte-cleanup.sh and disk-alert.sh to /opt/scripts/
#   - Sets up cron jobs (monthly cleanup + 6-hourly disk alert)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/opt/scripts"

echo "=== Airbyte Maintenance Scripts Installer ==="
echo ""

# --- Must run as root ---
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo ./deploy.sh)"
    exit 1
fi

# --- Step 1: Install scripts ---
echo "[1/3] Installing scripts to ${INSTALL_DIR}/"
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/airbyte-cleanup.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/disk-alert.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/airbyte-cleanup.sh"
chmod +x "$INSTALL_DIR/disk-alert.sh"
echo "  Done: airbyte-cleanup.sh installed"
echo "  Done: disk-alert.sh installed"

# --- Step 2: Set up cron jobs ---
echo ""
echo "[2/3] Setting up cron jobs"

CRON_CLEANUP="0 3 1 * * ${INSTALL_DIR}/airbyte-cleanup.sh >> /var/log/airbyte-cleanup.log 2>&1"
CRON_ALERT="0 */6 * * * ${INSTALL_DIR}/disk-alert.sh >> /var/log/disk-alert.log 2>&1"

# Remove any existing airbyte cron entries to avoid duplicates
EXISTING_CRON=$(crontab -l 2>/dev/null | grep -v 'airbyte-cleanup\|disk-alert' || true)

# Write new crontab
echo "$EXISTING_CRON" | { cat; echo "$CRON_CLEANUP"; echo "$CRON_ALERT"; } | crontab -
echo "  Done: Monthly cleanup — 1st of month at 3:00 AM UTC"
echo "  Done: Disk alert — every 6 hours"

# --- Step 3: Verify ---
echo ""
echo "[3/3] Verifying installation"
echo ""
echo "  Installed scripts:"
ls -la "$INSTALL_DIR"/airbyte-cleanup.sh "$INSTALL_DIR"/disk-alert.sh
echo ""
echo "  Cron jobs:"
crontab -l | grep -E 'airbyte-cleanup|disk-alert'
echo ""

# --- Dry run test ---
echo "=== Running dry-run test ==="
"$INSTALL_DIR/airbyte-cleanup.sh" --dry-run || {
    echo ""
    echo "Warning: Dry run failed — the Docker container may not be running."
    echo "  This is OK if you're deploying before Airbyte is started."
}

echo ""
echo "=== Installation complete ==="
echo ""
echo "Next steps:"
echo "  1. Test cleanup:  sudo ${INSTALL_DIR}/airbyte-cleanup.sh --dry-run"
echo "  2. Run cleanup:   sudo ${INSTALL_DIR}/airbyte-cleanup.sh"
echo "  3. Check logs:    tail -f /var/log/airbyte-cleanup.log"
echo "  4. Check disk:    sudo ${INSTALL_DIR}/disk-alert.sh"
