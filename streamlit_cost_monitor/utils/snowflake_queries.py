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
  4.x — Airbyte freshness (OPS views — not ACCOUNT_USAGE)
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import streamlit as st

if TYPE_CHECKING:
    import pandas as pd
    from snowflake.snowpark import Session

from .config import (
    ANOMALY_MULTIPLIER,
    CREDIT_PRICE_USD,
    DAILY_LOOKBACK_DAYS,
    STORAGE_HISTORY_DAYS,
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


def daily_cost_by_user(top_n: int = 5) -> str:
    """Per-day credit allocation to users over the default lookback window.

    Uses the same hourly-share allocation as :func:`cost_by_user_mtd`:
    warehouse credits in each hour are divided among users proportional
    to their execution_time in that hour.

    Returns one row per (usage_date, bucket) where ``bucket`` is the user
    name if they're in the top-N total spenders over the window, and
    ``'Other'`` otherwise. The top-N ranking is computed from the window
    total, not per-day, so a single column per user is stable across the
    chart — otherwise a user could flicker in and out of the legend.
    """
    return f"""
with wh_cost as (
    select
        warehouse_name,
        date_trunc('hour', start_time) as hr,
        sum(credits_used)              as credits
    from snowflake.account_usage.warehouse_metering_history
    where start_time >= dateadd('day', -{DAILY_LOOKBACK_DAYS}, current_timestamp())
    group by 1, 2
),
user_share as (
    select
        user_name,
        warehouse_name,
        date_trunc('hour', start_time) as hr,
        sum(execution_time)            as exec_ms,
        sum(sum(execution_time)) over (
            partition by warehouse_name, date_trunc('hour', start_time)
        )                              as total_exec_ms
    from snowflake.account_usage.query_history
    where start_time >= dateadd('day', -{DAILY_LOOKBACK_DAYS}, current_timestamp())
      and execution_status = 'SUCCESS'
      and warehouse_name is not null
    group by 1, 2, 3
),
per_user_daily as (
    select
        date_trunc('day', u.hr)::date as usage_date,
        u.user_name,
        sum(w.credits * u.exec_ms / nullif(u.total_exec_ms, 0)) as credits
    from user_share u
    join wh_cost w
        on u.warehouse_name = w.warehouse_name
       and u.hr            = w.hr
    group by 1, 2
),
ranked as (
    select
        user_name,
        sum(credits) as total_credits,
        rank() over (order by sum(credits) desc) as rnk
    from per_user_daily
    where credits > 0
    group by 1
),
labelled as (
    select
        p.usage_date,
        case when r.rnk <= {top_n} then p.user_name else 'Other' end as bucket,
        p.credits
    from per_user_daily p
    left join ranked r using (user_name)
)
select
    usage_date,
    bucket,
    round(sum(credits), 2)              as credits,
    round(sum(credits) * {_price()}, 2) as dollars
from labelled
where credits > 0
group by 1, 2
order by 1, 2
"""


def monthly_cost_by_warehouse(months: int = 6) -> str:
    """Snowflake compute credits + dollars per calendar month, last N months.

    The current month is partial — the Combined page flags it in the UI.
    """
    return f"""
select
    date_trunc('month', start_time)::date               as month,
    warehouse_name,
    round(sum(credits_used), 2)                         as credits,
    round(sum(credits_used) * {_price()}, 2)            as dollars
from snowflake.account_usage.warehouse_metering_history
where start_time >= dateadd('month', -{months - 1}, date_trunc('month', current_timestamp()))
group by 1, 2
order by 1, 2
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

    NOTE on HAVING: Snowflake resolves unqualified column names in HAVING
    against the FROM clause first, so `having credits > 0` would bind to
    `w.credits` (a non-grouped column) and fail compilation. We wrap the
    aggregation in a subquery and filter in WHERE instead.
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
),
allocated as (
    select
        u.user_name,
        u.role_name,
        round(
            sum(w.credits * u.exec_ms / nullif(u.total_exec_ms, 0)),
            2
        ) as credits,
        round(
            sum(w.credits * u.exec_ms / nullif(u.total_exec_ms, 0)) * {_price()},
            2
        ) as dollars
    from user_share u
    join wh_cost w
        on u.warehouse_name = w.warehouse_name
       and u.hr            = w.hr
    group by 1, 2
)
select user_name, role_name, credits, dollars
from allocated
where credits > 0
order by dollars desc
"""


def cost_by_query_tag_mtd() -> str:
    """Credit attribution by (QUERY_TAG, WAREHOUSE). Hourly-share allocation.

    Two dimensions so the page can render a stacked bar: each tag bar is
    split by warehouse, surfacing which tags run on shared vs. dedicated
    warehouses. ETL_WH carries both Airbyte (untagged in query_tag) and
    dbt layers; COMPUTE_WH carries Power BI.

    Relevant tags: ``dbt``, ``dbt:silver:*``, ``dbt:gold[:intermediate]``,
    ``dbt:snapshot``, ``dbt:seed``. Untagged queries (Airbyte inserts,
    Power BI reads, ad-hoc) roll up to ``<untagged>``.
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
),
allocated as (
    select
        t.query_tag,
        t.warehouse_name,
        round(sum(w.credits * t.exec_ms / nullif(t.total_exec_ms, 0)), 2) as credits,
        round(sum(w.credits * t.exec_ms / nullif(t.total_exec_ms, 0)) * {_price()}, 2) as dollars
    from tag_share t
    join wh_cost w
        on t.warehouse_name = w.warehouse_name
       and t.hr            = w.hr
    group by 1, 2
)
select query_tag, warehouse_name, credits, dollars
from allocated
where credits > 0
order by dollars desc
"""


# --------------------------------------------------------------------------- #
# 3. Deep dives
# --------------------------------------------------------------------------- #

def cost_anomalies() -> str:
    """Flag days where spend exceeds {ANOMALY_MULTIPLIER}× the 28-day rolling baseline.

    Snowflake's MEDIAN() can't be used with a sliding window frame, so we
    use AVG() as the baseline. A single extreme day does inflate the mean,
    but not enough to mask a subsequent anomaly at 2.5×.

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
with_baseline as (
    select
        usage_date,
        credits,
        dollars,
        avg(credits) over (
            order by usage_date
            rows between 28 preceding and 1 preceding
        )                                                     as avg_28d,
        count(*) over (
            order by usage_date
            rows between 28 preceding and 1 preceding
        )                                                     as window_size
    from daily
)
select
    usage_date,
    round(credits, 2)                      as credits,
    round(dollars, 2)                      as dollars,
    round(coalesce(avg_28d, 0), 2)         as baseline_28d_credits,
    case
        when window_size < 7         then 'insufficient-history'
        when credits > avg_28d * {ANOMALY_MULTIPLIER} then 'ANOMALY'
        else 'normal'
    end                                    as status
from with_baseline
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


# --------------------------------------------------------------------------- #
# 4. Airbyte freshness (reads AD_ANALYTICS.OPS views, not ACCOUNT_USAGE)
# --------------------------------------------------------------------------- #

@st.cache_data(ttl="1m")
def get_airbyte_freshness(_session: "Session") -> "pd.DataFrame":
    """Per-connection freshness — one RAG-status row per active connection.

    Cached for 1 minute (shorter than other tabs) because freshness is the
    entire point of this page — stale dashboard data defeats the purpose.

    Returns columns: connection_id, oldest_extracted_at, newest_extracted_at,
    staleness_min, table_count, warn_minutes, alert_minutes, status.
    staleness_min = age in minutes of the BUSIEST stream's last extract
    (the connection-level health signal — see view comment in
    setup/07_airbyte_observability.sql).
    Rows are ordered ALERT first, then WARN, then OK.
    """
    return _session.sql("""
        select
            connection_id,
            oldest_extracted_at,
            newest_extracted_at,
            staleness_min,
            table_count,
            warn_minutes,
            alert_minutes,
            status
        from ad_analytics.ops.v_airbyte_freshness
        order by
            case status when 'ALERT' then 0 when 'WARN' then 1 else 2 end,
            connection_id
    """).to_pandas()


@st.cache_data(ttl="1m")
def get_airbyte_freshness_per_stream(_session: "Session") -> "pd.DataFrame":
    """Per-stream detail for the expandable table on the Airbyte Health page.

    Returns columns: connection_id, stream, last_extracted_at, staleness_min.
    Sorted by staleness descending so the stalest stream is always at the top.

    Cached for 1 minute — same reasoning as get_airbyte_freshness.
    """
    return _session.sql("""
        select
            connection_id,
            stream,
            last_extracted_at,
            staleness_min
        from ad_analytics.ops.v_airbyte_freshness_per_stream
        order by staleness_min desc
    """).to_pandas()
