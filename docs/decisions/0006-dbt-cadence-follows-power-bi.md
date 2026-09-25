# 0006 — dbt builds on Power BI's cadence

**Status:** accepted; deployed 2026-04-28.

## Context

dbt ran every 10 minutes — 144 builds a day. Its consumer is Power BI, which a 14-day audit of
`ACCOUNT_USAGE.QUERY_HISTORY` (2026-04-28) showed refreshing every 15 minutes, at :00/:15/:30/:45 on
`COMPUTE_WH` — not daily, as the context files then claimed. No hour is dark: overnight it still
refreshes once or twice an hour.

## Decision

`cron(5,20,35,50 * * * ? *)` UTC: each build starts 5 minutes before a Power BI refresh. A build takes
~3.5 minutes (~6 cold), which leaves 4–7 minutes of margin.

## Why the cadence, and not idle-skip

`ETL_WH` spend is flat by hour of day — 17% between the quietest and the busiest hour (30-day audit,
2026-04-28) — because each build pays warehouse spin-up, ~$0.43, whatever it does. Spend is linear in
build count, so 144 → 96 builds a day saves ~$617 a month. Skipping builds when Iceberg is unchanged
was built and parked (branch `feat/dbt-idle-skip`): another ~$60–120 a month, for a far worse return
on its complexity.

## Consequences

- The Streamlit apps' average lag went from ~5 to ~7.5 minutes; 15 at worst.
- If builds outgrow the margin, the fallback is `cron(0,15,30,45 * * * ? *)`.
- Reverting is one call, targets untouched:
  `aws events put-rule --name ammodepot-dbt-build-schedule --schedule-expression "rate(10 minutes)" --state ENABLED --profile ammodepot`.
