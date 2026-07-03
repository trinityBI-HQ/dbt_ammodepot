# Experiment Record — Bounding Airbyte replication container memory

**Type:** Controlled production experiment (not a deployment). **Status:** BEFORE
baseline captured; **execution attempt 1 (2026-07-03) ABORTED at the apply step** by a
deployment-tooling defect (unpinned `abctl` chart version → unintended 2.1.0 upgrade;
see [`AIRBYTE_INSTALL.md`](./AIRBYTE_INSTALL.md) §Incident log). **Never reached the
propagation gate → no behavioral observations; the experiment remains NOT executed.**
Platform recovered to a clean 2.0.19 baseline; re-armed from Step 0 with version-pinned
install commands. **Investigation:** B (operational root cause).
**Related:** [`airbyte-values.yaml`](./airbyte-values.yaml), [`AIRBYTE_INSTALL.md`](./AIRBYTE_INSTALL.md).

> Filled now: Objective, Hypothesis, Expected mechanism, Success criteria, Rollback
> criteria, the BEFORE column of Observed Results, and the Unexpected observations (§8)
> + Retrospective (§9). Completed during/after the validation window: the AFTER column,
> the Conclusion verdict, and the recorded **confidence** level (§7).

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

This is a **stabilization experiment, not a deployment.** Passing the propagation
gate is necessary; the first healthy sync is encouraging; **neither proves the
mechanism is fixed.** The failure is intermittent (global OOMs ~1.3/h before), so
success is judged on a *new steady state* over an observation window — never on "did
the next sync succeed?"

**Gate (propagation — must pass FIRST, per [AIRBYTE_INSTALL.md](./AIRBYTE_INSTALL.md) §Verify Step 1):**
rendered pod spec + cgroup-v2 `memory.max` = 2 GiB on **both** source and dest, for
**both** connections (fishbowl + magento). If this fails, the experiment ends here
(no-op) → roll back; do not evaluate behavior.

**Observation window (defines "AFTER"):** once the gate passes, let the system run
**unattended ≥ 24 h**, crossing **≥ ~140 sync cycles per connection** (10-min cadence)
and **≥ several 2-connection overlaps** (worst-case concurrent memory pressure). At the
BEFORE rate (~1.3 global OOMs/h) a clean 24 h window would have had **~31 chances to
fail** — so passing by luck is near-impossible. Measure every signal over the **full
window** (rates, not a snapshot), and confirm the **tail** (last ~6 h) is as clean as
the head — a genuine steady state, not a transient post-reinstall calm.

**Primary (mechanism):** all 8 closure signals (Section 7) hold across the entire
window. **Secondary (JVM bound, S8):** source-JVM **peak RSS reaches a stable plateau
below 2 GiB** (validating the JVM now sizes off the cgroup limit, not the host).

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
AFTER" below holds **across the full observation window** (§4), not just at the start.
If S6/S7 fall but S1–S3 persist → symptom reduced, mechanism NOT fixed → H₁ incomplete.
AFTER values are the window aggregate (rate), with the tail confirmed as clean as the head.

| # | Signal | Metric | **BEFORE** (2026-07-03, ~19–24 h window) | Predicted AFTER (H₁) | **AFTER** (measured) | Verdict |
|---|---|---|---|---|---|---|
| S1 | **Global OOM events** | `constraint=CONSTRAINT_NONE…global_oom` / day | **25** (36 java procs killed), 00:08→19:17 ≈ 1.3/h | **0** | _tbd_ | _tbd_ |
| S2 | **containerd health** | context-deadline-exceeded + ttrpc-closed / day | **43 + 52** (+9 TaskOOM) | **≈0** | _tbd_ | _tbd_ |
| S3 | **kubelet NotReady** | "Node became not ready" / "runtime is down" / day | **3 / 16** | **0** | _tbd_ | _tbd_ |
| S4 | **workload-launcher restarts** | restart-count **delta** over window | lifetime **373** (worker 194, server 113, +270); actively climbing (worker +1 in last 15 m) | **0 new** | _tbd_ | _tbd_ |
| S5 | **replication pod lifecycle** | stuck-`NotReady` freezes / `OOMKilled` | **≥1 stuck NotReady now** (job 23631, 17 m); launcher last exit `Error:1` (DNS crash) | **0 stuck-freeze**; contained `OOMKilled` acceptable | _tbd_ | _tbd_ |
| S6 | **freeze frequency** | `airbyte_freeze_evidence` captures / day | **23** | **0** | _tbd_ | _tbd_ |
| S7 | **remediation frequency** | `airbyte_remediation_log` events / 24 h | **91** (72 BREAKER_OPEN, 6 AUTO_FIX, 13 ESCALATE, 4 kind-bounce) | **≈0** | _tbd_ | _tbd_ |
| S8 | **source-JVM peak RSS** | cgroup-v2 `memory.peak` per source, vs 2 GiB limit | **3.3–4.7 GiB** (host-OOM-truncated, no plateau — grew until the kernel killed it) | **stable plateau < 2 GiB** (~1.5 GiB heap + off-heap) | _tbd_ | _tbd_ |

Host at capture: node Ready, mem 6.6 GB used / 8.6 GB avail (between OOM spikes).

**S8 is the direct mechanism validation.** If H₁ holds we should see, per source pod:
(a) `memory.max` = 2 GiB (limit bound), (b) the JVM sizing off *that* limit not the host,
(c) `memory.peak` reaching a **stable plateau below 2 GiB** across many cycles, (d) zero
new global OOMs (S1). Together that is the mechanism observed directly, not inferred.
A contained per-container `OOMKilled` at exactly 2 GiB is acceptable (the intended safe
failure) and still validates H₁ — it means the cap held and the host was protected.

## 7. Conclusion

_To be completed after the observation window (§4). Pre-registered decision rule:_

### Investigation B closure checklist (ALL must hold across the FULL window)

Close B **with high confidence** only if every box is true over the whole steady-state
window (not the first sync):

- [ ] **1. Config propagated** — gate PASS: pod spec + `memory.max` = 2 GiB, both
      containers, both connections (fishbowl + magento).
- [ ] **2. JVM sizing as expected** — S8: source RSS plateaus stably **below 2 GiB**;
      no unbounded growth toward a host-sized ceiling.
- [ ] **3. Zero new global OOM** — S1 = 0 across the window.
- [ ] **4. containerd healthy** — S2 ≈ 0 (no context-deadline / ttrpc-closed storms).
- [ ] **5. kubelet stays Ready** — S3 = 0 NotReady transitions.
- [ ] **6. launcher restarts stabilize** — S4 delta = 0 (count flat across the window).
- [ ] **7. replication completes normally** — S5: jobs Complete; no stuck-`NotReady`
      freezes (contained `OOMKilled` acceptable).
- [ ] **8. freeze/remediation collapse** — S6 → 0 and S7 → ≈0.

**All 8 → MECHANISM FIXED → formally close Investigation B.** The entire cascade
disappeared, not just the symptom.

**Other outcomes:**
- **SYMPTOM REDUCED ONLY → keep investigating:** S6/S7 drop but S1–S4 persist. The fix
  helped but the cascade still fires by another path → H₁ incomplete; do not close B.
- **NO EFFECT / PROPAGATION FAILED → roll back:** gate fails or S1/pod-spec unchanged →
  the limit did not bind (discussion#72436 pod-manifest path) → DB-level fix required.

### Confidence (record separately from outcome — do not conflate)

State a confidence level with the conclusion, citing the evidence for it and what
remains unexplained. **Evidence, interpretation, and confidence are three different
things** and RCAs routinely blur them.

- **HIGH** — all 8 closure criteria satisfied across the full window; **S8 shows the
  sub-2 GiB plateau** (mechanism observed directly, not inferred); **no** contradictory
  observation. → Close Investigation B; stop A unless it answers a new question.
- **MEDIUM** — cascade collapsed and mechanism strongly supported, but 1–2 observations
  remain unexplained (e.g. noisy S8 plateau, a signal only partially cleared, an
  unexpected-but-non-contradicting event). → Close B provisionally; log the open items;
  do not over-claim.
- **LOW** — operational improvement (S6/S7 down) but the mechanism is **not** directly
  demonstrated (S8 inconclusive, or S1–S3 did not fully clear). Could be coincidence or
  a partial fix. → Do **not** close B; keep observing or reconsider H₁.

Record the level, the specific evidence supporting it, and every observation left
unexplained. **An unexplained observation caps confidence at MEDIUM** regardless of how
clean the headline numbers look.

### Then — revisit Investigation A (do not continue it by inertia)

Once B is closed, ask A a single question: **does A still answer an *unanswered*
question, or has the controlled experiment already provided sufficient evidence?**
If the experiment explains **both** the mechanism (why the JVM OOMs) **and** the
operational behavior (the whole cascade collapsing when bounded), then A's freeze-onset
FAE adds nothing new — **stop.** We set out to explain and stop the freeze; if the
evidence has done that, the project is complete. Only continue A if a closure box
*failed* in a way that points to a second, independent cause A could still isolate.

---

## 8. Unexpected observations

Findings the investigation surfaced that were **not** part of the original hypothesis
but are valuable engineering knowledge in their own right. Future operators may learn as
much from these as from the fix itself.

1. **Helm chart V1↔V2 key mismatch is silent.** `global.jobs.resources` (chart-V1) does
   not populate `JOB_MAIN_CONTAINER_MEMORY_LIMIT` in chart V2, so a limit set there is
   completely inert — no error, no warning. On abctl chart-V2 a values file is a
   *request*, not a guarantee; **only the rendered pod spec is truth.**
2. **"Config present" ≠ "config applied."** A 4 GiB limit sat in the live Helm values the
   whole time while the pods ran unbounded. This is why propagation is a **hard gate**,
   not a formality — and why the April migration silently regressed with nobody noticing.
3. **Out-of-band ops config becomes false institutional memory.** The believed "1 GiB
   limit" was a real patch — on a host (Airbyte 1.5.1) later discarded, never
   version-controlled, never carried to the new box; `ed0567ff` only deleted a planning
   doc. Un-versioned operational state drifts from belief. Version-controlling it (this
   PR) is the fix for that class of error.
4. **A persistent failure can decay before it can be cleanly captured.** In Investigation
   A, a freeze's onset evidence (k8s events, ~1 h TTL) aged out before its contamination
   (from manual recovery bounces) cleared — captured fresh-but-contaminated OR
   clean-but-decayed, never both. **The observer can destroy the evidence;** operational
   triage and RCA had to be kept strictly separate.
5. **On single-node kind, an unbounded container is a NODE-level availability risk.** The
   global OOM did not merely kill the offending JVM — it left *containerd itself*
   unresponsive (`context deadline exceeded`), cascading to node `NotReady` and a
   control-plane crash-loop. The blast radius of one unbounded workload container is the
   **whole platform**, not just that container. (This is why S2/S3 are first-class signals.)
6. **The safety net can fight the diagnosis.** The auto-remediation Lambda's kind-bounce,
   triggered by the stale freshness a contained `OOMKilled` produces, would destroy the
   exact pod state the experiment must observe — hence the "pause remediation during the
   window" precondition. Automated recovery and controlled observation are in tension.

## 9. Retrospective — the investigation in four phases

1. **Detection** — understand the symptom; quantify the freezes (signature
   `bytesSynced=0, lastUpdatedAt=null`; ~23/day).
2. **Instrumentation** — build and *validate* the evidence collector before trusting any
   evidence; establish trustworthy, contamination-classified observations.
3. **Root-cause analysis** — identify the operational failure chain; eliminate competing
   hypotheses; reconcile the historical configuration (V1/V2 key, `ed0567ff`).
4. **Scientific validation** — controlled experiment: propagation verification →
   steady-state observation → evidence-based closure with recorded confidence.

If H₁ validates and the full cascade disappears, this RCA will have demonstrated, end to
end: **what failed, why it failed, why the fix should work, that it actually propagated,
that it eliminated the mechanism (not just the symptom), and the explicit evidence and
confidence under which the investigation was closed.** At that point the project is
complete — not because "the system works again," but because the mechanism is understood
and its removal is demonstrated.

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
# S8 source-JVM peak RSS vs limit (cgroup v2 high-water mark — no sampling needed)
SRCID=$(sudo docker exec $CP crictl ps --name source --state Running -q | head -1)
sudo docker exec $CP crictl exec $SRCID sh -c 'echo "max=$(cat /sys/fs/cgroup/memory.max) peak=$(cat /sys/fs/cgroup/memory.peak) current=$(cat /sys/fs/cgroup/memory.current)"'
# PASS: max=2147483648 (2Gi); peak plateaus BELOW max across cycles (no OOMKilled at max).
# Sample across several syncs of BOTH connections; memory.peak is per-container-lifetime,
# so read it late in each sync. (Fallback if memory.peak absent: poll `crictl stats $SRCID`.)
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
