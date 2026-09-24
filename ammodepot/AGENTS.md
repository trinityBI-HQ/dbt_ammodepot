# ammodepot/ — the dbt project

Production dbt project (dbt-core + dbt-snowflake). Airbyte lands Fishbowl (ERP) and Magento
(e-commerce) as Iceberg in `AD_ANALYTICS.LAKEHOUSE_LANDING`; this project builds
`AD_ANALYTICS.SILVER` and `AD_ANALYTICS.GOLD`, and **Power BI reads Gold directly**. Production
builds run on ECS every 15 minutes — how, and the race that implies, is in `../ecs/AGENTS.md`.

## This project's conventions override the shared dbt rule

The shared `dbt-conventions` rule loads here and describes a different layout. This project predates
it, and Power BI has Gold's schema cached, so the layout below stands:

| Layer | Here |
|---|---|
| Bronze | source YAML only — `bronze_{source}_sources.yml`, no SQL models |
| Silver | views named `{source}_{entity}` (`fishbowl_so`, `magento_sales_order`), snake_case — except the inventory measures, `silver/inventory/inventory_{metric}`; 7 high-fan-out models are tables |
| Gold | tables `d_{entity}` / `f_{entity}` with **UPPER_CASE columns**; `f_sales` is incremental (merge, 3-day lookback) |
| Intermediate | `int_{source}_{purpose}` views, built in the gold schema; 3 bottlenecks are tables |

All configuration lives in `dbt_project.yml` — no per-model `config()`. Silver filters
`_ab_cdc_deleted_at is null` and dedups with `qualify row_number()`. Dialect-specific SQL goes through
the `adapter.dispatch` macros in `macros/cross_db/`. Business values are vars, never literals.

## Never

- **Remove, rename or retype a Gold column without the matching Power BI change.** Power BI reads
  Gold as-is; `models/gold/_exposures.yml` says who reads what.
- **Narrow a Gold model's date window because of its name.** `f_sales_realtime` keeps ≥ 4 days: a
  1-day rewrite once blanked Power BI's *Yesterday* card for two weeks. Power BI slices dates
  in DAX, not in the source SQL.
- **Touch `D_PRODUCT`'s quoted mixed-case columns** (`"Product ID"`, `"Caliber"`, …) — Power BI
  depends on them. A new consumer gets an UPPERCASE wrapper view, as `int_product_analyst` does for
  Cortex Analyst.
- **`ref()` a table a Snowflake Task manages.** `F_FORECAST` and `F_ANOMALIES` fail at parse; use
  `ad_analytics.gold.f_forecast` directly.
- **Key anything on `rank_id`.** It is `row_number()` over emails and shifts every time a customer
  is added. Use `customer_email`, or a surrogate generated from it.

## Traps

- **Joining `magento_customer_entity` on email fans out** — Magento multistore registration gives one
  email several `entity_id`s (~0.4% of customers). Dedup at the join, not in Silver:
  `qualify row_number() over (partition by lower(email) order by customer_id) = 1`. It broke
  `snap_customer_segmentation` on every run for a week.
- **Epoch-ms columns** (`_airbyte_extracted_at` on Iceberg) compared to `current_timestamp()`: use
  `to_timestamp_ltz(x, 3)`. `to_timestamp` yields NTZ and bakes in the session-timezone offset.
- **Iceberg types differ from the legacy tables**: `_airbyte_extracted_at` is NUMBER (epoch ms) and
  business timestamps are TIMESTAMP_LTZ. Gold models feeding Power BI cast `convert_timezone`
  results back to TIMESTAMP_NTZ to keep its cached schema.
- **SQL stored procedures reject `ALTER SESSION`**, `QUERY_TAG` included.
- **`AD_ANALYTICS.OPS` belongs to `STREAMLIT_ROLE`** — `TRANSFORMER_ROLE` cannot create objects there.
- **Gold is not the only read path.** `AD_AIRBYTE` holds a hand-written Silver/Gold/realtime layer
  dbt does not manage: `../docs/architecture/warehouse.md`.

## Sources

- Bronze sources point at the 55 unmanaged Iceberg tables in `LAKEHOUSE_LANDING` (34 Fishbowl, 21
  Magento) with explicit `identifier:`. **They never refresh on their own, and a local `dbt build` does
  not refresh them**: `../ecs/refresh_iceberg.py` does, from the ECS entrypoint before every scheduled
  build, and the build is skipped if it fails. The `on-run-start` hook that used to do it is gone.
- Freshness: Fishbowl and Magento warn at 24h, error at 48h, on `_airbyte_extracted_at`.
- **Magento product attributes are EAV**, resolved in `int_magento_product_eav_lookups` and
  `int_magento_product_attributes`; attribute ids are the `ammodepot_magento_attr_id_*` vars.
- **UPS** is a weekly manual CSV upload into `PC_FIVETRAN_DB.UPS_INVOICE_HISTORY`, joined to
  Fishbowl `shipcarton` by tracking number. No freshness check — the cadence is manual.
- **GunBroker orders exist only in Fishbowl** (GB-prefixed SOs) and enter `f_sales` through
  `int_fishbowl_gunbroker_sales`, with negative IDs (`-1 × fishbowl id`) so they never collide with
  Magento's. Fishbowl status 60 means completed and archived, not an estimate.
- `ammodepot_excluded_order_skus` drops a whole order when any line matches. The client decides
  what joins the list.

## ML

Cortex ML training is dbt macros, not stored procedures: `macros/ml_forecast.sql`, run with
`dbt run-operation train_all_ml_models --target prod`. ANOMALY_DETECTION needs training and
detection windows that do not overlap. What the models feed: `../docs/architecture/ai-features.md`.

## Before calling a change done

Run `dbt build` against it. When a change moves row counts, dedup or join cardinality, also prove it
on production data, read-only, and put the before/after counts in the PR:

```bash
set -a && source .env && set +a
uv run dbt compile --profiles-dir . --target prod --select <model>
uv run dbt show --profiles-dir . --target prod --inline "
with fixed as ($(cat target/compiled/ammodepot/models/<path>/<model>.sql))
select count(*) as rows, count(distinct <pk>) as keys, count(*) - count(distinct <pk>) as dupes from fixed"
```

dbt does not load `.env` by itself, hence the `set -a` line. `SVC_DBT` / `TRANSFORMER_ROLE` can read
`SNOWFLAKE.ACCOUNT_USAGE` query and metering history — enough for cost audits without ACCOUNTADMIN.
