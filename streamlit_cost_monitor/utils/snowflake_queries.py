"""Snowflake ACCOUNT_USAGE queries for the cost monitor.

All queries:
  - Read from ``SNOWFLAKE.ACCOUNT_USAGE`` (requires IMPORTED PRIVILEGES, already
    granted to STREAMLIT_ROLE by the bootstrap SQL).
  - Filter on the underlying timestamp columns (never aliases — Snowflake
    doesn't allow column-alias references in WHERE).
  - Cost-in-dollars is computed with ``:credit_price`` bound at call-time so
    the rate lives in one place (:mod:`utils.config`).

Query numbering follows the dashboard layout:
  1.x — Top-line spend (daily trend, MTD scorecards)
  2.x — Dimensional breakdowns (warehouse, user, query_tag)
  3.x — Deep dives (top queries, anomalies, storage)
"""

from __future__ import annotations

from .config import (
    ANOMALY_MULTIPLIER,
    CREDIT_PRICE_USD,
    DAILY_LOOKBACK_DAYS,
    STORAGE_HISTORY_DAYS,
    TOP_QUERIES_LOOKBACK_DAYS,
)


def _price() -> float:
    return CREDIT_PRICE_USD


# --------------------------------------------------------------------------- #
# 1. Top-line spend
# --------------------------------------------------------------------------- #

def mtd_summary() -> str:
    """MTD credits + dollars + vs prior month MTD-to-date for the same day count."""
    return f"""
with mtd as (
    select
        sum(credits_used) as credits,
        sum(credits_used) * {_price()} as dollars,
        datediff('day', date_trunc('month', current_date()), current_date()) + 1 as days_elapsed
    from snowflake.account_usage.warehouse_metering_history
    where start_time >= date_trunc('month', current_timestamp())
),
prior as (
    select sum(credits_used) as credits
    from snowflake.account_usage.warehouse_metering_history
    where start_time >= dateadd('month', -1, date_trunc('month', current_timestamp()))
      and start_time <  date_trunc('month', current_timestamp())
      and date_trunc('day', start_time) < dateadd('day',
            (select days_elapsed from mtd),
            dateadd('month', -1, date_trunc('month', current_timestamp())))
)
select
    round(mtd.credits, 2)                              as credits_mtd,
    round(mtd.dollars, 2)                              as dollars_mtd,
    round(coalesce(prior.credits, 0), 2)               as credits_prior_mtd,
    round(coalesce(prior.credits, 0) * {_price()}, 2)  as dollars_prior_mtd,
    mtd.days_elapsed                                    as days_elapsed
from mtd
cross join prior
"""


def daily_cost_by_warehouse() -> str:
    return f"""
select
    date_trunc('day', start_time)::date                 as usage_date,
    warehouse_name,
    round(sum(credits_used), 2)                         as credits,
    round(sum(credits_used) * {_price()}, 2)            as dollars
from snowflake.account_usage.warehouse_metering_history
where start_time >= dateadd('day', -{DAILY_LOOKBACK_DAYS}, current_timestamp())
group by 1, 2
order by 1
"""


# --------------------------------------------------------------------------- #
# 2. Dimensional breakdowns (MTD)
# --------------------------------------------------------------------------- #

def cost_by_warehouse_mtd() -> str:
    return f"""
select
    warehouse_name,
    round(sum(credits_used), 2)                 as credits,
    round(sum(credits_used) * {_price()}, 2)    as dollars
from snowflake.account_usage.warehouse_metering_history
where start_time >= date_trunc('month', current_timestamp())
group by 1
order by dollars desc
"""


def cost_by_user_mtd() -> str:
    """Allocate warehouse credits to users proportionally by execution_time.

    Matches the generated dashboard's logic but uses a single CTE and binds
    the credit price so there's exactly one source of truth for the rate.
    """
    return f"""
with wh_cost as (
    select
        warehouse_name,
        date_trunc('hour', start_time) as hr,
        sum(credits_used)              as credits
    from snowflake.account_usage.warehouse_metering_history
    where start_time >= date_trunc('month', current_timestamp())
    group by 1, 2
),
user_share as (
    select
        user_name,
        role_name,
        warehouse_name,
        date_trunc('hour', start_time) as hr,
        sum(execution_time)            as exec_ms,
        sum(sum(execution_time)) over (
            partition by warehouse_name, date_trunc('hour', start_time)
        )                              as total_exec_ms
    from snowflake.account_usage.query_history
    where start_time >= date_trunc('month', current_timestamp())
      and execution_status = 'SUCCESS'
      and warehouse_name is not null
    group by 1, 2, 3, 4
)
select
    u.user_name,
    u.role_name,
    round(
        sum(w.credits * u.exec_ms / nullif(u.total_exec_ms, 0)),
        2
    )                                                             as credits,
    round(
        sum(w.credits * u.exec_ms / nullif(u.total_exec_ms, 0)) * {_price()},
        2
    )                                                             as dollars
from user_share u
join wh_cost w
    on u.warehouse_name = w.warehouse_name
   and u.hr            = w.hr
group by 1, 2
having credits > 0
order by dollars desc
"""


def cost_by_query_tag_mtd() -> str:
    """Credit attribution by QUERY_TAG. Uses the same hourly-share allocation.

    Relevant tags for this pipeline: ``dbt:gold``, ``dbt:silver``, Airbyte
    inserts, Streamlit session tags. Untagged queries roll up to ``<untagged>``.
    """
    return f"""
with wh_cost as (
    select
        warehouse_name,
        date_trunc('hour', start_time) as hr,
        sum(credits_used)              as credits
    from snowflake.account_usage.warehouse_metering_history
    where start_time >= date_trunc('month', current_timestamp())
    group by 1, 2
),
tag_share as (
    select
        coalesce(nullif(query_tag, ''), '<untagged>') as query_tag,
        warehouse_name,
        date_trunc('hour', start_time)                 as hr,
        sum(execution_time)                            as exec_ms,
        sum(sum(execution_time)) over (
            partition by warehouse_name, date_trunc('hour', start_time)
        )                                              as total_exec_ms
    from snowflake.account_usage.query_history
    where start_time >= date_trunc('month', current_timestamp())
      and execution_status = 'SUCCESS'
      and warehouse_name is not null
    group by 1, 2, 3
)
select
    t.query_tag,
    round(sum(w.credits * t.exec_ms / nullif(t.total_exec_ms, 0)), 2) as credits,
    round(sum(w.credits * t.exec_ms / nullif(t.total_exec_ms, 0)) * {_price()}, 2) as dollars
from tag_share t
join wh_cost w
    on t.warehouse_name = w.warehouse_name
   and t.hr            = w.hr
group by 1
having credits > 0
order by dollars desc
limit 25
"""


# --------------------------------------------------------------------------- #
# 3. Deep dives
# --------------------------------------------------------------------------- #

def top_expensive_queries() -> str:
    """Top 15 by execution time across ALL warehouses (no hardcoded filter)."""
    return f"""
select
    substr(query_text, 1, 120)                        as query_preview,
    warehouse_name,
    user_name,
    role_name,
    query_tag,
    round(max(total_elapsed_time) / 1000.0, 1)        as exec_sec,
    round(max(bytes_scanned) / power(1024, 3), 2)     as gb_scanned,
    count(*)                                          as n_runs
from snowflake.account_usage.query_history
where start_time >= dateadd('day', -{TOP_QUERIES_LOOKBACK_DAYS}, current_timestamp())
  and execution_status = 'SUCCESS'
group by all
order by exec_sec desc
limit 15
"""


def cost_anomalies() -> str:
    """Flag days where spend > {ANOMALY_MULTIPLIER}× the 28-day rolling median.

    Returns the last 30 days so you see the current window plus history.
    """
    return f"""
with daily as (
    select
        date_trunc('day', start_time)::date        as usage_date,
        sum(credits_used)                          as credits,
        sum(credits_used) * {_price()}             as dollars
    from snowflake.account_usage.warehouse_metering_history
    where start_time >= dateadd('day', -60, current_timestamp())
    group by 1
),
with_median as (
    select
        usage_date,
        credits,
        dollars,
        median(credits) over (
            order by usage_date
            rows between 28 preceding and 1 preceding
        ) as median_28d
    from daily
)
select
    usage_date,
    round(credits, 2)                      as credits,
    round(dollars, 2)                      as dollars,
    round(coalesce(median_28d, 0), 2)      as median_28d_credits,
    case
        when median_28d is null then 'insufficient-history'
        when credits > median_28d * {ANOMALY_MULTIPLIER} then 'ANOMALY'
        else 'normal'
    end                                    as status
from with_median
where usage_date >= dateadd('day', -30, current_date())
order by usage_date desc
"""


def storage_current_snapshot() -> str:
    return """
select
    database_name,
    round(average_database_bytes / power(1024, 3), 2)                         as active_gb,
    round(average_failsafe_bytes / power(1024, 3), 2)                         as failsafe_gb,
    round((average_database_bytes + average_failsafe_bytes) / power(1024, 3), 2) as total_gb
from snowflake.account_usage.database_storage_usage_history
where usage_date = current_date() - 1
  and average_database_bytes > 0
order by total_gb desc
"""


def storage_growth_by_database() -> str:
    return f"""
select
    usage_date,
    database_name,
    round(average_database_bytes / power(1024, 3), 2) as active_gb,
    round(average_failsafe_bytes / power(1024, 3), 2) as failsafe_gb
from snowflake.account_usage.database_storage_usage_history
where usage_date >= dateadd('day', -{STORAGE_HISTORY_DAYS}, current_date())
  and average_database_bytes > 0
order by usage_date, database_name
"""
