# airbyte-ec2/ — the Airbyte platform

Airbyte runs under **abctl (kind/k8s) on one EC2 host**, `i-075043415ebad732f` (c6a.2xlarge, 16 GB,
AL2023; root volume `vol-06a30feea2ddc25d0`, 160 GB gp3, XFS — it grows online), and writes Fishbowl
and Magento as Iceberg to S3. **Access is SSM only** — no SSH, no SCP: `aws ssm start-session --target i-075043415ebad732f --profile ammodepot`.

| Read first | For |
|---|---|
| `README.md` | the maintenance scripts, their timers and logs |
| `AIRBYTE_INSTALL.md` | install/re-apply, and **why connection-level `resourceRequirements` is the memory knob** |
| `CAPACITY_PLANNING.md` | host envelope, connector sizing, the Magento bistable loop |
| `EXPERIMENT.md` | the replication-OOM investigation (closed) |
| `../docs/AIRBYTE_INCIDENT_RUNBOOK.md` | a stuck sync: cancel + restart |

## Before changing anything here

- **Pin the chart.** `abctl local install` without `--chart-version` pulls upstream's latest, turning
  a values change into a platform upgrade. A failed cross-version upgrade cannot be rolled back in
  place (`AIRBYTE_INSTALL.md`, incident log). Run abctl as `sudo env HOME=/usr/bin abctl …` — its
  state lives in `/usr/bin/.airbyte/`. Why abctl stays despite its friction:
  `../docs/decisions/0009-keep-airbyte-on-abctl.md`; the April in-place upgrade this host replaced:
  `../docs/decisions/0007-airbyte-2-upgrade-plan.md`.
- **`abctl local uninstall --persisted` deletes the data**; without the flag it keeps it.
- **`/tmp` is a 7.7 GB tmpfs.** Staging a large file there fills RAM and makes cluster creation fail
  silently.
- **Nothing deploys this directory.** No workflow covers `airbyte-ec2/`: a merge changes nothing on
  the host until `deploy.sh` runs there (`README.md` → Deployment). Check the host, not git.
- **`server` runs an absolute `-Xmx1200m`, never `MaxRAMPercentage`.** A percentage hands any room
  added to the cap to the heap, and the pod dies again, higher: 6× worse at 2 GiB. Replication pods
  keep the stock 75%, which tracks their fixed per-connection cap. Both are argued in
  `airbyte-values.yaml`; the history is `../docs/incidents/2026-07-27-control-plane-oom-and-alert-thrash.md`.
- **After any `abctl local install`, check two settings by hand**: `server`'s live `JAVA_OPTS` (its
  precedence over the chart is unproven — the command is in `airbyte-values.yaml`), and
  `airbyte-db`'s memory bound, a live patch the chart cannot persist.
- **Roll out the control plane at minutes `:x6`–`:x9`.** Magento syncs start at `:x0` and Fishbowl at
  `:x5` (schedules as of 2026-08); a sync whose orchestrator starts while `server` restarts is orphaned.
- **Scheduled jobs are systemd timers.** AL2023 ships no cron — the first `deploy.sh` wired jobs with
  `crontab`, scheduled nothing, and the disk filled to 100%
  (`../docs/incidents/2026-07-15-airbyte-disk-full.md`).

## Disk: retention is the dial

Every attempt stores a full catalog snapshot in `attempts.attempt_sync_config` — ~5 MB × ~298
attempts a day ≈ **1.5 GB/day of live data**, so steady state is a multiple of `RETENTION_DAYS`
(14 → ~21 GB). A clean prune plus a full disk means the data is live, not bloat: the fix is retention
or a bigger volume. **`VACUUM FULL` is rarely right** — it needs free space ≥ the table and reclaims
only dead rows; `disk-alert.sh` computes this rather than recommending it.

## Operating it

- **Airbyte's public API returns 500 on any endpoint that resolves a source or connection** while
  connection-level `resourceRequirements` are set (an NPE in its mapper). Restart syncs through the
  internal `POST /api/v1/connections/sync`; the jobs list and `DELETE /jobs/{id}` still work. API
  credentials are OAuth client credentials in the `airbyte-auth-secrets` k8s secret — read them with
  `docker exec airbyte-abctl-control-plane kubectl …`, since the cluster was created as root.
- **Bouncing the control plane: `docker restart -t 120` — never without `-t`.** Ten seconds of grace
  SIGKILLs containerd mid-write and corrupts it: 13 hours down
  (`../docs/incidents/2026-09-19-remediation-13h-outage.md`). A reboot does not fix that corruption.
- **Stopping the host (stop, resize): stop kubelet, then containerd, then the container** —
  `docker stop -t 180`. `docker stop` measured 1 m 31 s even with containerd already stopped, so
  Docker's 10 s default always SIGKILLs it. The restart policy is `on-failure`: after an instance
  stop/start, `docker start airbyte-abctl-control-plane` may be needed by hand.
  ```bash
  D='docker exec airbyte-abctl-control-plane'
  $D systemctl stop kubelet && sleep 5 && $D systemctl stop containerd && sleep 8
  docker stop -t 180 airbyte-abctl-control-plane
  ```
- **An expired CDC offset needs a connection refresh** — no retry or bounce repairs it. Use
  `airbyte-connection-refresh.py`, which carries the traps (`Truncate` for these `append`
  connections, never `Merge`) and what to expect; it needs the host resized first.
- **Any control-plane restart orphans in-flight syncs**: the pod shows `3/3 Running`, counters stay at
  0, nothing self-heals, and Airbyte will not start another sync on that connection. After one, check
  for a live job that is not moving and cancel + restart it by hand.
- **A bounce does not clear a stuck job** — it reclassifies it. Data moves again only with the next
  scheduled sync or an explicit cancel + restart.
- **SSM**: an instant `Failed`, `PT0S`, with empty stdout *and* stderr while the agent pings Online
  means the root disk is full. In payloads carrying JSON, write `echo "KEY=$VAR"` — `${VAR:-{}}`
  mis-parses the brace.
