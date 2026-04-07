# Iceberg cutover archive — 2026-04-07

Files preserved from the day of the Iceberg cutover. None of this is
runnable production code today; it's here for historical reference and
emergency rollback context.

## What happened on 2026-04-07

The ammodepot pipeline was migrated from "Airbyte writes directly to
Snowflake tables in `AD_AIRBYTE.AD_FISHBOWL.*` and `AD_MAGENTO.*`" to
"Airbyte writes Parquet files to S3, registered as Iceberg tables in
`AD_ANALYTICS.LAKEHOUSE_LANDING.*` via External Volume + Glue Catalog
Integration, and Snowflake reads them directly."

Net result: SVC_AIRBYTE Snowflake compute dropped from ~22.6 cr/hr to
~0 cr/hr. Verified savings: ~$2,000/month (~$24,000/year).

Mid-cutover we discovered Power BI was reading from two hand-built
views in `AD_AIRBYTE.AD_REALTIME` that consumed the legacy ingestion
tables (NOT from dbt's `AD_ANALYTICS.GOLD.*` as we had assumed). When
the legacy Airbyte → Snowflake connections were disabled, those views
froze. We rewrote both as thin passthroughs of the dbt-managed Gold
tables to restore freshness.

## Files

### `legacy_f_sales_realtime_lastdays.sql`

The original ~500-line implementation of
`AD_AIRBYTE.AD_REALTIME.F_SALES_REALTIME_LASTDAYS` before the rewrite.
25 CTEs, custom Magento↔Fishbowl identity mapping, hand-rolled cost
fallback hierarchy, freight allocation by weight inside order, custom
JSON parsing of Fishbowl `customfields`. All of this logic was already
implemented inside the dbt project (`int_fishbowl_order_cost`,
`int_magento_order_freight`, `int_sales_cost_fallback`,
`magento_d_customerupdated`, etc.) so the rewrite collapsed to a
36-column passthrough of `AD_ANALYTICS.GOLD.F_SALES` filtered to the
last 4 days.

This file is the source of truth for the legacy semantics. If anyone
reconciles dashboards against pre-cutover numbers and sees a delta,
this is what their old numbers came from. It is NOT runnable today
because it depends on `AD_AIRBYTE.AD_FISHBOWL.SO`, `AD_MAGENTO.SALES_ORDER`,
etc., which are now stale (last write 2026-04-07 17:00 UTC) and may
be dropped entirely later.

### `legacy_f_sales_realtime.sql`

The original ~100-line implementation of
`AD_AIRBYTE.AD_REALTIME.F_SALES_REALTIME` before the rewrite. Same
story as above: read directly from `AD_AIRBYTE.AD_MAGENTO.SALES_ORDER_ITEM`,
filtered to today's orders in America/New_York timezone, computed
`DISTINCT_ORDER_ID_COUNT` and `DISTINCT_ORDER_ID_BY_TESTSKU` measures.

After Power BI was repointed to read directly from
`AD_ANALYTICS.GOLD.F_SALES_REALTIME` (the dbt-managed model), the
wrapper view became dead code. It was kept in place per user direction
on the day of the cutover but is queued for removal in the broader
`AD_AIRBYTE` audit.

### `lakehouse_parallel_validation.py`

Standalone Python script used during the cutover to validate that the
new Iceberg path (`LAKEHOUSE_LANDING.*`) was producing row-for-row
equivalent data to the legacy `AD_AIRBYTE.*` path. Compares deduped
row counts, max CDC timestamps, set differences, and tombstone counts
across three high-volume tables (`fishbowl.so`, `fishbowl.soitem`,
`magento.sales_order`). Reusable as a regression check if the
architecture changes again.

To run:

```bash
cd ammodepot/
set -a && source .env && set +a
uv run python ../archive/sql/2026-04-07-iceberg-cutover/lakehouse_parallel_validation.py
```

Note: legacy `AD_AIRBYTE` data is frozen at the cutover moment, so
this script will show large drift when run after 2026-04-07 — that's
expected, not a regression.

## Related context

- Memory file: `project_lakehouse_architecture.md` — full cutover state
  and tomorrow-review queue
- Code commits: `c5621d56` (Bronze swap), `bdb5c4d6` (NULL-PK fix),
  `9d64a83f` (NTZ cast for PBI), `63519cb3` (Python sidecar refresh)
- The rewritten views live in `AD_AIRBYTE.AD_REALTIME` (Snowflake);
  they are NOT in this dbt project's source tree
