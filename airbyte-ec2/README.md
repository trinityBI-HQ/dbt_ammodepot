# Airbyte EC2 Maintenance Scripts

Maintenance scripts for the Airbyte EC2 instance (`ip-10-0-1-105`, c6i.2xlarge, us-east-1).
Airbyte runs on Kind (Kubernetes in Docker). The instance is accessed via AWS Session Manager only — no SSH.

## Scripts

| Script | Purpose | Schedule |
|---|---|---|
| `airbyte-cleanup.sh` | Deletes job logs and DB history older than 30 days, then VACUUMs | 1st of month at 3:00 AM UTC |
| `disk-alert.sh` | Logs a warning if disk usage exceeds 70% | Every 6 hours |
| `deploy.sh` | Installs the above two scripts and registers cron jobs | Run once per deployment |

### airbyte-cleanup.sh

Reclaims disk space by removing stale sync artifacts:

1. Counts Minio job log directories and DB records older than the retention window (preview step, always runs)
2. Deletes Minio job log directories from `/var/local-path-provisioner/airbyte-minio-pv/airbyte-storage/job-logging/workspace`
3. Deletes rows from `stream_attempt_metadata`, `stream_stats`, `sync_stats` (FK dependents of `attempts`)
4. Deletes rows from `attempts` and `jobs`
5. Runs `VACUUM` on all five tables

Default retention: 30 days. Override with `RETENTION_DAYS=N`.

```bash
# Preview what would be deleted — no changes made
sudo /opt/scripts/airbyte-cleanup.sh --dry-run

# Run cleanup
sudo /opt/scripts/airbyte-cleanup.sh

# Override retention window
sudo RETENTION_DAYS=14 /opt/scripts/airbyte-cleanup.sh
```

### disk-alert.sh

Checks host disk usage. If usage is at or above the threshold (default 70%), logs:
- Current disk percentage
- Top 5 directories under `/var/local-path-provisioner/` inside the Kind container
- Top 5 PostgreSQL tables by size

Below threshold, logs an OK message and exits.

```bash
# Run manually
sudo /opt/scripts/disk-alert.sh

# Override threshold
sudo DISK_THRESHOLD=80 /opt/scripts/disk-alert.sh
```

### deploy.sh

Copies both scripts to `/opt/scripts/`, sets executable permissions, and writes two cron entries to root's crontab. Existing `airbyte-cleanup` and `disk-alert` entries are removed before writing to prevent duplicates.

Finishes with a dry-run of `airbyte-cleanup.sh` to verify the Docker container is reachable.

---

## Deployment

Access the instance via AWS Session Manager, then run the installer.

**Step 1 — Connect via Session Manager**

```bash
aws ssm start-session --target <instance-id> --region us-east-1
sudo su -
```

**Step 2 — Copy scripts to the instance**

From your local machine, use SSM document `AWS-RunShellScript` or upload files through S3 then pull them down. Alternatively, paste the script contents using a heredoc block (recommended for Session Manager sessions):

```bash
cat > /tmp/airbyte-cleanup.sh << 'EOF'
<paste contents of airbyte-cleanup.sh>
EOF
cat > /tmp/disk-alert.sh << 'EOF'
<paste contents of disk-alert.sh>
EOF
cat > /tmp/deploy.sh << 'EOF'
<paste contents of deploy.sh>
EOF
chmod +x /tmp/deploy.sh
```

**Step 3 — Run the installer**

```bash
cd /tmp && sudo ./deploy.sh
```

The installer prints installed paths, cron entries, and the dry-run result.

---

## Logs

| Log file | Written by |
|---|---|
| `/var/log/airbyte-cleanup.log` | `airbyte-cleanup.sh` (via cron) |
| `/var/log/disk-alert.log` | `disk-alert.sh` (via cron) |

```bash
# Follow cleanup log
tail -f /var/log/airbyte-cleanup.log

# Check last disk alert run
tail -50 /var/log/disk-alert.log

# Confirm cron jobs are registered
crontab -l | grep -E 'airbyte-cleanup|disk-alert'
```

---

## Troubleshooting

**Cleanup exits with "Container is not running"**

The script checks that `airbyte-abctl-control-plane` is listed in `docker ps`. If Airbyte is down, start it before running cleanup.

```bash
docker ps --filter name=airbyte-abctl-control-plane
```

**Dry run passes but live run fails on psql step**

The script reaches the DB via `docker exec ... kubectl exec ... psql`. Verify the `airbyte-db-0` pod is running inside Kind:

```bash
docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl
```

**Disk is still high after cleanup**

Run the disk alert script manually to identify the top consumers. Docker image layers and Kind node images are common culprits outside the Minio path:

```bash
sudo /opt/scripts/disk-alert.sh
df -h /
du -d 1 -h /var/lib/docker/ | sort -rh | head -10
```

**Cron not firing**

Verify the cron daemon is running and the entries are under root's crontab (deploy.sh writes to root):

```bash
systemctl status cron || systemctl status crond
sudo crontab -l
```
