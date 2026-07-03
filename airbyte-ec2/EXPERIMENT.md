# Experiment Record — Bounding Airbyte replication container memory

**Type:** Controlled production experiment (not a deployment). **Status:** BEFORE
baseline captured; awaiting execution. **Investigation:** B (operational root cause).
**Related:** [`airbyte-values.yaml`](./airbyte-values.yaml), [`AIRBYTE_INSTALL.md`](./AIRBYTE_INSTALL.md).

> Filled sections: Objective, Hypothesis, Expected mechanism, Success criteria,
> Rollback criteria, and the BEFORE column of Observed Results. AFTER + Conclusion
> are completed during the validation window.

---

## 1. Objective

Determine whether setting a bounded cgroup memory limit (2 GiB) on the Airbyte
replication **source and destination** containers eliminates the recurring sync
freeze **and its entire failure cascade** — i.e. establish whether we fixed the
*mechanism* or merely reduced a *symptom*.

## 2. Hypothesis

The freeze is caused by unbounded replication JVMs. Each `source-mysql` / `dest-s3-data-lake`
container runs Airbyte's stock `-XX:MaxRAMPercentage=75.0` with **no cgroup memory
limit**, so the Java 21 JVM sizes max heap off the **host's 16 GB** (~11.4 GiB) and
grows into it until the host is exhausted, triggering a **global** kernel OOM.

**H₀ (null):** bounding memory changes nothing material — freezes/cascade persist.
**H₁ (ours):** binding a 2 GiB cgroup limit makes the JVM size off the limit (~1.5 GiB
heap), caps total RSS at 2 GiB, and converts any overrun into a **contained
per-container `OOMKilled`** — removing the global OOM and therefore the whole cascade.

## 3. Expected mechanism

```
BEFORE:  unbounded JVM (heap off 16 GB host) → global host OOM (CONSTRAINT_NONE)
         → containerd unresponsive → kubelet: node NotReady "runtime is down"
         → cluster DNS breaks → workload-launcher crash-loop → replication stuck → FREEZE

AFTER:   JVM heap off 2 GiB limit (~1.5 GiB) → RSS capped at 2 GiB by cgroup
         → (worst case) contained per-container OOMKilled → one sync retried
         → NO global OOM → containerd stable → node stays Ready → launcher stable
         → replication completes → NO FREEZE
```

If H₁ is correct, the fix acts at the **first link** (global OOM), so **every**
downstream link should disappear — not just the visible freeze.

## 4. Success criteria

**Gate (propagation — must pass FIRST, per [AIRBYTE_INSTALL.md](./AIRBYTE_INSTALL.md) §Verify Step 1):**
rendered pod spec + cgroup-v2 `memory.max` = 2 GiB on **both** source and dest, for
**both** connections (fishbowl + magento). If this fails, the experiment ends here
(no-op) → roll back; do not evaluate behavior.

**Primary (mechanism):** in an AFTER window ≥ the BEFORE window (≥ ~24 h / ~96 sync
cycles), **all 7 cascade signals collapse to ≈ 0** (Section 6). This is the
mechanism-fixed result.

**Secondary (JVM bound):** source RSS plateaus < 2 GiB through full syncs of both
connections (was climbing to ~4 GB).

## 5. Rollback criteria

The pre-armed 7-trigger table in [`AIRBYTE_INSTALL.md`](./AIRBYTE_INSTALL.md) §Rollback
governs. Any single trigger (propagation failure, destination/magento/source
`OOMKilled` recurring, helper failures, throughput drop, or freeze-frequency worse)
fires the rollback command. Preconditions (Investigation-A freeze released,
auto-remediation paused `observe-only=true`, rollback artifact committed, low-traffic
window) must all hold before execution.

## 6. Observed results — cascade-signal harness

**Method:** each signal measured with the *identical* read-only command before and
after (Appendix A). Event-rate signals (S1–S3, S6–S7) compared over equal-length
windows or as per-hour rates; S4 as restart-count **delta** over the window; S5
qualitative + `OOMKilled` count.

**Pre-registered prediction (falsifiable):** if H₁ is correct, every "Predicted
AFTER" below is ≈ 0. If S6/S7 fall but S1–S3 persist → symptom reduced, mechanism
NOT fixed → H₁ incomplete.

| # | Signal | Metric | **BEFORE** (2026-07-03, ~19–24 h window) | Predicted AFTER (H₁) | **AFTER** (measured) | Verdict |
|---|---|---|---|---|---|---|
| S1 | **Global OOM events** | `constraint=CONSTRAINT_NONE…global_oom` / day | **25** (36 java procs killed), 00:08→19:17 ≈ 1.3/h | **0** | _tbd_ | _tbd_ |
| S2 | **containerd health** | context-deadline-exceeded + ttrpc-closed / day | **43 + 52** (+9 TaskOOM) | **≈0** | _tbd_ | _tbd_ |
| S3 | **kubelet NotReady** | "Node became not ready" / "runtime is down" / day | **3 / 16** | **0** | _tbd_ | _tbd_ |
| S4 | **workload-launcher restarts** | restart-count **delta** over window | lifetime **373** (worker 194, server 113, +270); actively climbing (worker +1 in last 15 m) | **0 new** | _tbd_ | _tbd_ |
| S5 | **replication pod lifecycle** | stuck-`NotReady` freezes / `OOMKilled` | **≥1 stuck NotReady now** (job 23631, 17 m); launcher last exit `Error:1` (DNS crash) | **0 stuck-freeze**; contained `OOMKilled` acceptable | _tbd_ | _tbd_ |
| S6 | **freeze frequency** | `airbyte_freeze_evidence` captures / day | **23** | **0** | _tbd_ | _tbd_ |
| S7 | **remediation frequency** | `airbyte_remediation_log` events / 24 h | **91** (72 BREAKER_OPEN, 6 AUTO_FIX, 13 ESCALATE, 4 kind-bounce) | **≈0** | _tbd_ | _tbd_ |

Host at capture: node Ready, mem 6.6 GB used / 8.6 GB avail (between OOM spikes).

## 7. Conclusion

_To be completed after the AFTER window. Pre-registered decision rule:_

- **MECHANISM FIXED → close Investigation B:** S1, S2, S3 → 0 **and** S4 delta ≈ 0
  **and** S5 no stuck-freeze **and** S6, S7 → 0. The entire cascade disappeared, not
  just the symptom. (Then revisit Investigation A: does its freeze-onset RCA still add
  value, or has the controlled experiment already answered it?)
- **SYMPTOM REDUCED ONLY → keep investigating:** S6/S7 drop but S1–S3 persist. The fix
  helped but the cascade still fires by another path → H₁ incomplete; do not close B.
- **NO EFFECT / PROPAGATION FAILED → roll back:** Step-1 gate fails or S1/pod-spec
  unchanged → the limit did not bind (discussion#72436 pod-manifest path) → DB-level
  fix required.

---

## Appendix A — collection commands (run identically BEFORE and AFTER)

`CP=airbyte-abctl-control-plane; NS=airbyte-abctl` — all read-only, via SSM `send-command`.

```bash
# S1 global OOM (host kernel)
sudo journalctl -k --no-pager -S today | grep -c 'constraint=CONSTRAINT_NONE.*global_oom'
# S2 containerd health (kind node)
sudo docker exec $CP journalctl -u containerd --no-pager -S today | grep -c 'context deadline exceeded'
sudo docker exec $CP journalctl -u containerd --no-pager -S today | grep -cE 'ttrpc: (received message on inactive stream|closed)'
# S3 kubelet NotReady (kind node)
sudo docker exec $CP journalctl -u kubelet --no-pager -S today | grep -cE 'Node became not ready|container runtime is down'
# S4 restart counts (delta = after - before)
sudo docker exec $CP kubectl get pods -n $NS --no-headers | grep -E 'workload-launcher|abctl-server|abctl-worker'
# S5 replication lifecycle
sudo docker exec $CP kubectl get pods -n $NS --no-headers | grep replication-job
sudo docker exec $CP kubectl get pods -n $NS -o jsonpath='{range .items[*]}{.metadata.name}|{range .status.containerStatuses[*]}{.name}={.lastState.terminated.reason}:{.lastState.terminated.exitCode} {end}{"\n"}{end}' | grep -iE 'replication|OOM'
```

```sql
-- S6 freeze frequency (Snowflake; USE ROLE TRANSFORMER_ROLE)
select to_date(capture_time) d, count(*) n
from ad_analytics.ops.airbyte_freeze_evidence
where capture_time >= dateadd('day',-2,current_timestamp()) group by 1 order by 1 desc;
-- S7 remediation frequency
select action_taken, outcome, count(*) n
from ad_analytics.ops.airbyte_remediation_log
where event_time >= dateadd('day',-1,current_timestamp()) group by 1,2 order by 3 desc;
```
