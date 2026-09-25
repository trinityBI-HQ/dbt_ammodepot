# 0008 — Auto-remediation: one Lambda outside the host

**Status:** accepted in stages, 2026-05-03 → 2026-07-02; its detection is being redesigned in TRI-19.

## Context

Syncs froze — a live job, zero bytes, no progress — and each freeze needed someone to cancel and
restart it over SSM. Done by hand on 2026-05-03, that took ~30 seconds end to end.

## Decision

A Lambda on the freshness schedule acts on the host through SSM. Tier 1 cancels and restarts the
sync; Tier 2 restarts the kind control plane (`docker restart -t 120`). Both sit behind observe-only
switches and a per-connection DynamoDB circuit breaker, and every decision writes an audit row. Design
and operation: `../../lambda/airbyte_auto_remediate/README.md`.

It is a workaround, not a fix. The freezes' cause — connector heaps sized off the host — was found by
Investigation B: `../../airbyte-ec2/EXPERIMENT.md`.

## Alternatives

- **Moving Airbyte from abctl/kind to Docker Compose** — deferred 2026-05-04. Two incidents were too
  small a sample; the move was 1–2 weeks with cutover risk; Compose is deprecated from Airbyte 2.0;
  and it might only relocate the problems. The kind-bounce was built first, at a fraction of the cost.
- **A separate Health Evaluator service** — observe, classify, decide and execute as components, with
  8 failure states — rejected 2026-07-02 at two connections. An evaluator that is down or stale, state
  skew, and split brain over the breaker would fire more often than the incidents it manages, and a
  *stored* verdict in front of a destructive restart is one more layer that can lie. Adopted instead:
  the same seam **inside** the Lambda, as pure functions and a failure-state enum, with telemetry kept
  as a durable append-only timeline collected off the remediation path. Extract a service when there
  are ~6–8 connections with divergent failure modes, when classification changes force re-testing the
  executor, when a second consumer of health state appears, or when classifying threatens the 900 s
  limit.

## Consequences

- **It recovers; it cannot keep data under an hour.** A 30-day audit (2026-07-02) found Magento 78
  minutes stale on average and 200 at worst: alert threshold, 15-minute cadence, the 2-hour breaker
  and the 60-minute deep-stuck gate put a persistent freeze at ~2 h 45 m before the bounce.
- **Destination freshness is a proxy that lies** — it cannot tell failing, idle, not-yet-refreshed and
  frozen apart. Both September incidents came from acting on it (`../incidents/`); TRI-19 moves
  detection to Airbyte's own state.
