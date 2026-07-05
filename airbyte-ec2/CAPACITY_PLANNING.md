# Capacity Planning — Airbyte large-CDC workload sizing

**Type:** Production-optimization workstream (NOT root-cause analysis). **Opened:** 2026-07-05.
**Status:** Recovery **EXECUTED 2026-07-05** (guarded controlled drain) — Magento drained + caught up, platform stable, cap **held at 3 GiB** (per-connector). Active workstream = steady-state observation → maintenance-window sizing decision. **See §0.**
**Predecessor:** [`EXPERIMENT.md`](./EXPERIMENT.md) — Investigation B (RCA) is **CLOSED**; the
platform-wide global-OOM cascade is eliminated. This workstream inherits the *contained*
residual, not a platform failure.

> **Scope boundary (keep it clean).** Investigation B answered *why the platform failed*
> and removed it. This workstream answers *how to operate the platform efficiently* as CDC
> workloads grow. The RCA does not depend on any conclusion here; nothing here reopens the RCA.

---

## 0. Recovery executed (2026-07-05) — validated findings

Experiment 1 (§6) was executed as a **production recovery** (owner prioritized service restoration
over the sizing step-down). Outcome:

- **Drain succeeded:** job 23848 committed **81,724 records in one 4.5-min pass at 3 GiB**; the CDC
  checkpoint advanced `mysql-bin-changelog.037229/59421641 → 037286` (+57 binlog files); the next
  sync advanced +1 file ⇒ **Magento caught up**. Freshness 707 min ALERT → OK; ~46k rows landed.
- **Platform stability preserved:** zero global OOM, node Ready throughout, min host-avail **4.7 GiB**
  (guards never near the 1.5 GiB abort floor). Fishbowl healthy.
- **Pivotal question (§4.1) — answered from observation:** demand is **backlog-proportional**, not a
  fixed structural floor near 2 GiB. Evidence: emitted-at-OOM grew 1:1 with the ~9k rec/hr CDC rate;
  genuine pre-freeze incrementals committed under 2 GiB; source cold-start floor ≈ **0.7 GiB**;
  destination (previously unmeasured) ≈ **0.65–0.9 GiB** — never the constraint.
- **Propagation model CORRECTED (supersedes §3a):** the **connection-level `resourceRequirements`
  GOVERNS** rendered replication-pod memory. Raising the launcher env alone did NOT change the pods —
  the Magento connection's leftover RR=2Gi overrode it. **Precedence: connection RR > actor RR >
  launcher inline env > `:0`.** ⇒ **per-connector sizing works.** Applied cleanly: Magento connection
  RR = **3 GiB** (LARGE), Fishbowl connection RR = **2 GiB** (SMALL) — no global raise required.
- **Live config (normal operation restored):** Magento 3 GiB / Fishbowl 2 GiB via connection RR;
  launcher fallback 3 GiB; auto-remediation live; both connections active + healthy.
  `airbyte-values.yaml` intentionally still 2 GiB (divergence recorded here, not silent drift —
  persist during the maintenance window).

**OPEN (Capacity Planning, not RCA):** the first post-drain incremental peaked **~2.7 GiB** on the
source — above the pre-freeze estimate. Whether settled steady-state is **≤2 GiB (transient — clean
step-down)** or **~2.5 GiB (structural — 3 GiB correctly sized)** is the input to a future
maintenance-window step-down decision. Observe several normal cycles first; do **not** step down
immediately after recovery. Auto-remediation follow-up: distinguish a backlog spiral from a transient
hang (don't cancel a committing drain).

---

## 1. Objective

Determine the correct **sizing model for large CDC workloads** on this platform:
1. How much memory does a LARGE CDC workload actually require to complete?
2. Is the 2 GiB global limit too conservative for large CDC — and by how much?
3. Is the current large-workload memory need **temporary** (accumulated CDC backlog) or
   **steady-state**? *(pivotal — it changes the operational decision entirely)*
4. What platform configuration (memory cap + concurrency + host size) scales safely as
   additional large connectors are added?

Guiding constraints (owner): no re-introduction of global-OOM risk; connector-specific
memory overrides are a **last resort** (they do not propagate on this build — see §3);
prefer proper capacity planning / scheduling over guessing a larger global limit.

---

## 2. Measured evidence base (read-only, 2026-07-04/05)

**Magento = the LARGE stress-case connector** (source-mysql via SSH tunnel to RDS MySQL
8.0.42; 21 CDC incremental-append streams; **828 tables** exist in the DB and are all
scanned by the binlog reader; dest = S3 data-lake, shared with Fishbowl):

- Under the global **2 GiB cap** (~1.5 GiB heap at `MaxRAMPercentage=75`) Magento's source
  throws **`java.lang.OutOfMemoryError: Java heap space`** → exit 3, after emitting only
  **~45–54 MB / ~60k records / 13 streams**. `memory.peak` pegs at **exactly 2 GiB**,
  `oom_kill=0` (JVM heap OOM, *not* a cgroup kill). The ~30:1 heap-to-output ratio ⇒ heap is
  consumed by CDC/Debezium buffering + concurrency-2 + the 828-table binlog scan, not by
  output volume.
- **CDC checkpoint is stuck**: every retry requests the *identical* binlog offset
  (`mysql-bin-changelog.037229 / 59421641`), `records_committed=0`, and emitted bytes
  **grow** across retries (45→54 MB) → a self-perpetuating backlog death-spiral (no commit →
  offset never advances → each retry re-reads a *larger* gap → more heap → OOM).
- **Fishbowl (SMALL)** is healthy at 2 GiB: ~2-min syncs, every 10 min, small data.
- Historical pre-fix **unbounded** source RSS: **3.3–4.7 GiB** — but this is an *upper bound
  on convenience*, not a lower bound on necessity (under a ~12 GiB heap ceiling the JVM
  defers GC and RSS overstates the live-set). The true floor must be measured as
  **live-set-after-full-GC**, which no evidence yet provides.
- **Overlap is structural**: Fishbowl (10-min period) lands ⌈30/10⌉ = **3 starts inside every
  ~30-min Magento window** regardless of offset. Only concurrency limiting removes overlap.
  Concurrency is currently **unbounded** (2 concurrent jobs observed).

**Host (measured):** usable **U ≈ 15.25 GiB**; control-plane + system floor **F ≈ 5.5 GiB
quiesced → 6.6–6.8 GiB under the current Magento-failure churn** — and **all control-plane
pods are UNBOUNDED**, so F is a *range that can drift*, not a hard constant. Budget for sync
jobs ≈ **U − F ≈ 8.5–9.7 GiB**. Worst-case job peak = `orchestrator(1 GiB) + source(cap) +
dest(cap)` = **1 + 2·cap** (dest memory itself is **unmeasured** — a known gap).

---

## 3. Capacity model (evidence-graded)

### 3a. Propagation constraint (proven — a design boundary, not a research task)
Per-connection memory does **NOT** propagate on this 2.1.0 build: `actor.resource_requirements`
and `connection.resource_requirements` are ignored by the launcher pod-builder (a fresh pod
rendered `source limits.memory=0` while both were set to 2 GiB; only the launcher's *global*
env changed the rendered limit). **⇒ the single global cap applies to every connector.** A
Magento-only cap is unavailable and is the evidence-forced last resort, not a design goal.

### 3b. Connector sizing tiers — **1 validated point, 2 hypotheses** (do not over-read)
| Tier | Example | Cap | Status |
|---|---|---|---|
| SMALL | Fishbowl (~2 min, tiny, low concurrency) | **2 GiB** | ✅ **validated** |
| MEDIUM | *(no example exists yet)* | ~3 GiB | ⚠️ interpolated hypothesis |
| LARGE | Magento (21 streams, 828-table binlog scan, ~30 min) | **unknown** | ❓ **the number Experiment 1 exists to find** — Magento has never completed at any cap |

### 3c. Safe operating envelope of the 16 GB host + the unsafe threshold
Job budget = `U − F`. Worst-case job = `1 + 2·cap`. All thresholds carry **±0.3–0.5 GiB**
(the budget mixes `free`, working-set, and cgroup accountings):

| Concurrency | Worst-case-safe global cap |
|---|---|
| **C = 2 (today, unbounded)** | **~1.66–1.94 GiB** (band; higher F → lower ceiling) |
| **C = 1 (serialized)** | **~3.0 GiB** (4 GiB breaches even serialized) |

**Key finding:** at **C=2**, today's **2 GiB cap already exceeds the worst-case budget**
(`2×(1+4)=10 GiB > 8.65 GiB`) and survives only on realistic RSS < cap. **Raising the global
cap while concurrency stays unbounded re-arms the exact cascade Investigation B removed.**
Corollary: a true worst-case no-global-OOM guarantee requires **bounding concurrency
(`MAX_SYNC_WORKERS`) and/or capping the control-plane pods** — today the platform has neither.

---

## 4. Open questions (ranked)

1. **PIVOTAL — temporary vs steady-state.** Measured evidence *leans transient* (all hard
   signals are backlog signatures); a modest structural floor above 2 GiB is *plausible but
   unmeasured*. This flips the decision: transient → one-time drain + keep 2 GiB, no capex;
   steady-state > ~2.5–3 GiB → the 16 GB box can't run it concurrently → capacity plan.
2. **True LARGE-CDC minimum** = live-set-after-full-GC on a *drained* incremental (unknown).
3. **Concurrency policy** — should `MAX_SYNC_WORKERS=1` be a standing precondition (worst-case
   safety) vs. the Fishbowl-freshness cost (10 min → ~30–40 min if serialized)?
4. **Long-term host sizing** — if steady-state is structural, size the box to the number of
   *concurrent* large connectors, not the total. (m6a.2xlarge 32 GiB ≈ **+$29/mo**; size to
   **cap-4**, not cap-5, for genuine future headroom.)
5. **Destination memory** — unmeasured, yet it appears as `cap` in every worst-case equation.

---

## 5. Levers (ranked, corrected)

0. **Break the backlog spiral first** — but *disambiguate*: advancing the Debezium offset to
   binlog head is cheap but **skips events → a data gap in the append-only S3 lake**;
   Airbyte "Reset data" is clean but triggers a **full re-snapshot = the heaviest** memory
   case. Not "free"; pick deliberately.
1. **Bound concurrency (`MAX_SYNC_WORKERS`)** — the only worst-case no-global-OOM guarantee;
   $0; cost = Fishbowl freshness if serialized. Arguably a **standing precondition**.
2. **`MaxRAMPercentage` 75 → ~88 %** — cheapest steady-state margin (~+0.3 GiB heap at the
   same 2 GiB cgroup, zero host-budget / zero OOM-cascade cost). Won't beat a *growing*
   backlog, but the best free steady-state lever.
3. **Bigger box (m6a.2xlarge 32 GiB, +~$29/mo)** — the durable answer *iff* steady-state is
   structural; keeps concurrency=2 and worst-case-cap safety. Size to cap-4.
4. **Source concurrency 2 → 1** (`DATA_CHANNEL_MEDIUM=STDIO`) — free, harmless to Fishbowl,
   relief uncertain (removes socket overhead, not the dominant Debezium buffering).
5. **Control-plane hygiene** (~1 GiB; the 2.34 GiB airbyte-server is churn-inflated) — do
   **not** hard-cap the server below its working set (it would OOM the whole control plane).

---

## 6. Experiment 1 — Controlled drain + steady-state measurement (FIRST optimization experiment)

**Goal:** resolve the pivotal unknown (§4.1) and pin the LARGE-CDC minimum. **Not yet run —
requires owner approval; it deliberately crosses "no production changes" with guards.**

**Corrected design (the naive "raise global cap to 6 GiB and drain" is UNSAFE on this host —
a 6 GiB-cap job's worst case is `1+2×6 = 13 GiB` ≫ the 8.65 GiB budget; max guard-compliant
cap here is ~3 GiB):**

- **Phase 0 — quiesce + isolate.** Auto-remediation `observe-only=true`; serialize
  (`MAX_SYNC_WORKERS=1` or pause Fishbowl). Record a **quiesced baseline** (`free -m`, per-pod
  RSS — F drops toward ~5.5 GiB once churn stops) and the starting checkpoint.
- **Phase 1 — instrument.** JVM **live-set-after-full-GC** (GC logs / `jcmd`) **and the
  destination JVM**, not just cgroup `memory.peak`.
- **Phase 2 — drain within guards.** Serialized, raise global cap to a **guard-compliant
  ≤ 3 GiB** and restart Magento. **Master datum: does the binlog checkpoint ADVANCE past
  `037229/59421641` with `records_committed > 0`?** If it will not drain at ≤ 3 GiB, do **not**
  escalate the cap into the OOM zone — instead either advance the offset (accept the data gap)
  or grow the box first.
- **Phase 3 — characterize steady-state.** Once drained, run the *next* incremental and step
  the cap down (3 → 2.5 → 2 GiB, one cadence per step). Lowest cap that completes with margin =
  **steady-state minimum** ⇒ transient (≤2 GiB) vs structural (>~2.5 GiB) verdict.
- **Phase 4 — cheap discriminator.** Set source concurrency=1 (`DATA_CHANNEL_MEDIUM=STDIO`),
  re-run at 2 GiB — if it now fits, concurrency-2 buffering was the swing factor.
- **Phase 5 — restore.** Global cap → 2 GiB (or validated steady min *only* with a concurrency
  + control-plane plan). Re-enable Fishbowl, then auto-remediation once a committing cycle is stable.

**Non-negotiable guards:** `observe-only=true` throughout; only ONE big job runs; live
`avail` + `oom_kill` + node-status watch with **hard abort at `avail < 1.5 GiB`, any
`oom_kill`, or node NotReady**; one variable per step; never a global cap whose worst-case
`1+2·cap` exceeds `U − F` in isolation; time-box the drain (~60–75 min) → then reset the
checkpoint rather than escalate RAM.

**Decision from the result:** steady ≤ 2 GiB → keep 2 GiB + a checkpoint-safety mechanism,
**no capex**. Steady > ~3 GiB → provision the 32 GiB box (keep the 2 GiB global-guardrail
philosophy, with room to raise the cap under worst-case safety) rather than raising the
global cap on the 16 GB host.

---

## 7. Bottom line
16 GB is at its ceiling — safe for one LARGE + one SMALL connector only on *probabilistic*
headroom, not worst-case. The pivotal question (transient vs steady-state) is cheaply
measurable, but the measurement is a **quiesced, serialized, ≤ 3 GiB drain — never a 6 GiB
cap raise** — and **no box purchase precedes a measured, drained incremental.**
