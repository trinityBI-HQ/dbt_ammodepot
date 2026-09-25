# 2026-07-27 — Control-plane OOM, a remediation that could only kill, and alert thrash

Found while investigating "lots of alert email and a webserver error". Three failures compounded.

## 1. The control plane was the OOM victim

All 9 platform pods ran with `resources={}` (BestEffort), and 5 of them with
`-XX:MaxRAMPercentage=75.0` — so each JVM sized its heap off the 16 GB host: `server` 2.44 GiB,
`cron` 2.12 GiB, `workload-api-server` 1.57 GiB, **8.5 GiB in total** against ~2.4 GiB budgeted.
With Magento's replication at 5 GiB source + 5 GiB destination on 15.25 GiB usable, the kernel hit a
global OOM — and BestEffort made the **control plane** its victim (restarts: launcher 45, worker 33,
server 8). A dead `airbyte-server` takes the API, the UI and remediation's ability to restart
anything with it.

**PR #34** bounded 8 pods: host available memory 5.3 → 8.6 GiB, no global OOM since. `airbyte-db`
cannot be persisted — the chart exposes no `postgresql.resources` — so its bound is a live patch that
every reinstall loses.

## 2. Auto-remediation could only kill

Airbyte's public API returned 500 on every restart (an NPE while connection-level memory caps are
set), so the Lambda spent days cancelling healthy Magento syncs and starting nothing — and it cancelled
them young: `bytesSynced=0` read as a freeze, but counters publish on commit, and Magento job 30043 died
at 83 seconds old. PR #34 moved the restart to the internal API and added the job-age floor
(`SKIP_JOB_TOO_YOUNG`); the Lambda went back to observe-only pending a soak.

## 3. Alert thrash

A global 25/30-minute threshold sat below normal data age: 126 of 544 Fishbowl gaps breached 25
minutes, ~27 emails in 26 hours. Thresholds became per connection and the WARN tier was suspended
(PR #35) — the measurement is in `../architecture/airbyte-observability.md`.

## Sequel: bounding `server` too tightly (2026-07-27 → 2026-08-13)

The bound traded the global OOM for a cgroup OOM in one pod: **114 kills in 13 days, all of them
`airbyte-abctl-server`**. At 1536Mi with a 75% heap, 384Mi was left for non-heap, which Micronaut and
Netty need. A sync whose orchestrator started inside a restart window never reached `RUNNING` and sat
`3/3 Running` with no reaper — Fishbowl lost 4 hours on 2026-08-10.

- **2Gi at 65% (PR #37, reverted): 6× worse**, dying at 2036Mi. It was justified by "RSS at kill ≈ the
  cap, so that is the working set" — circular: RSS at kill always equals the cap; that is what an OOM
  kill is. Read together, the two points show non-heap growing into whatever room is left.
- **Fixed by PR #40 (2026-08-13):** 2Gi, **absolute `-Xmx1200m`**, `MALLOC_ARENA_MAX=2` — the three only
  work together. 15 hours without a kill, checked against `dmesg` rather than container counters;
  resident memory settles near 1768Mi of 2048. What unlocked it was measuring heap and non-heap
  separately (`-XX:NativeMemoryTracking=summary` and `/proc/1/smaps`).

The reasoning and the load-bearing settings are recorded in `airbyte-values.yaml`, next to them.

**The 114 kills went unseen** — nothing watched pod restarts, and freshness only notices once a sync
has already wedged. PR #39 (2026-08-11) added the watch: the Lambda samples the control plane's
`restartCount` on every run and pages on 3 restarts in 24 hours. PR #38 cut the rest of the noise —
a successful auto-fix pages only on its third for one connection in 24 hours.
