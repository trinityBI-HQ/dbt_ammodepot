---
paths: ["lambda/airbyte_auto_remediate/**", "airbyte-ec2/**"]
---
# 2026-09-19 — Auto-remediation turned a Magento fault into a 13-hour outage

The worst self-inflicted incident so far: ingestion stopped for about 13 hours — **Fishbowl
included**, which had nothing wrong with it.

## The chain

1. **~22:50 UTC — Magento's CDC offset expired.** `Incumbent CDC state is invalid ... Saved offset no
   longer present on the server`: the connector was at `mysql-bin-changelog.043239` and the server's
   oldest was `043278`, a 39-file gap. `failureType: config_error`; every sync failed in ~60 s from
   then on. **Only a connection refresh repairs this.**
2. **The remediation could not tell "failing" from "frozen".** It measures destination freshness, and
   a connection failing every 10 minutes looks exactly like a frozen one. The gate sent a `failed`
   last job straight to `ACT`, so the ladder ran: cancel + restart (nothing to cancel) → verification
   inconclusive (the fault is permanent) → kind-bounce.
3. **The kind-bounce corrupted containerd.** `docker restart` without `-t` allows 10 s; the kind node
   cannot stop kubelet, containerd and every shim in that time, so containerd was SIGKILLed mid-write
   and came back with duplicate container-name records. CRI aborted on every start
   (`failed to recover state: failed to reserve container name ... is reserved for`), kubelet
   crash-looped 36,894 times, and there was no API server.

## Recovery — about 10 minutes, nothing lost

**A reboot does not fix this**: the corrupt metadata lives in `/var/lib/containerd` on the host bind
mount and survives any restart.

```bash
D='docker exec airbyte-abctl-control-plane'
$D systemctl stop kubelet containerd
$D cp -n /etc/containerd/config.toml /etc/containerd/config.toml.bak-preclean
$D sed -i '2a disabled_plugins = ["io.containerd.grpc.v1.cri"]' /etc/containerd/config.toml
$D systemctl start containerd                       # core API up, CRI off: ctr works
$D sh -c 'ctr -n k8s.io containers ls -q | xargs -r -n1 ctr -n k8s.io containers rm'
$D rm -rf /var/lib/containerd/io.containerd.grpc.v1.cri /run/containerd/io.containerd.grpc.v1.cri
$D cp /etc/containerd/config.toml.bak-preclean /etc/containerd/config.toml
$D systemctl restart containerd && $D systemctl start kubelet
```

114 container records removed, 58 images untouched, the node back `Ready` with 78 days of etcd state;
Airbyte recreated every pod and scheduled its own catch-up.

**The diagnosis order that found it:** `systemctl status airbyte-cleanup` (it failed at 03:05, which
dated the outage) → `docker ps` (the container is up, so Docker is fine) → `kubectl get nodes`
(refused) → `systemctl is-active kubelet containerd` (kubelet `activating` is the tell) →
`journalctl -u containerd`, reading only `level=fatal` — the plugin-loading lines are noise.

## Fixes (PR #42)

- `docker restart -t 120`, readiness 120 → 180 s, `KIND_BOUNCE_SSM_RECONCILE_SECONDS` 240 → 420, so a
  slow but successful bounce is not classified as failed.
- **`SKIP_JOB_FAILED`**: a `failed` or `cancelled` last job never triggers infrastructure action; it
  emails a human, at most once per `FAILED_JOB_NOTIFY_COOLDOWN_HOURS` (12). Airbyte already retries a
  failed sync every 10 minutes, so restarting one adds nothing. No job at all still returns `ACT`, so
  freeze recovery is unchanged.

## Repairing Magento, 2026-09-20 (TRI-9)

A connection refresh with `airbyte-ec2/airbyte-connection-refresh.py` (PR #43), whose docstring
carries the two traps — the mode enum is capitalised, and an `append` connection is refreshed with
`Truncate`, never `Merge`. The source re-read everything in ~5 minutes, the offset moved to `043360`,
and freshness went from 894 to 4 minutes. Generation 0 stays readable while generation 1 is written,
so Power BI never saw an empty table.

The cleanup that follows deletes old-generation files one Iceberg commit at a time — ~21 files a
minute against ~22,300, 16–18 hours with no incremental syncs — so it was cancelled. The landing
tables keep about 4× the rows (`magento_sales_order` 7.8 M against 1.8 M), which Silver's
`QUALIFY ROW_NUMBER()` collapses to the right count. Rows deleted during the outage carry no CDC
delete marker and survive until generation 0 is expired — TRI-14.

The snapshot needs ~5 GiB source + ~5 GiB destination, so the host ran as c6a.4xlarge for the
refresh and went back to c6a.2xlarge the same day. `docker stop` took 1 m 31 s on both shutdowns —
the graceful stop sequence is in `airbyte-ec2/AGENTS.md`.

**Until the binlog retention on the MySQL source is raised, the offset can expire again** — TRI-10.
