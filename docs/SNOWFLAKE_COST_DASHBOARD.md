# Snowflake Cost & Usage Monitoring Dashboard

**Date:** 2026-03-23
**Stack:** Streamlit + Snowflake + dbt-core
**Target:** Streamlit page in `streamlit_app/` (local + SiS compatible)

---

## 1. Data Sources — Snowflake Metadata Views

All data comes from Snowflake's built-in `SNOWFLAKE` shared database. No external ingestion needed.

| View | Schema | What It Provides | Latency |
|---|---|---|---|
| `WAREHOUSE_METERING_HISTORY` | `ACCOUNT_USAGE` | Credits consumed per warehouse per hour | ~3 hours |
| `QUERY_HISTORY` | `ACCOUNT_USAGE` | Every query: warehouse, user, role, credits, bytes, duration | ~3 hours |
| `WAREHOUSE_LOAD_HISTORY` | `ACCOUNT_USAGE` | Concurrency, queued, blocked queries per warehouse | ~3 hours |
| `METERING_HISTORY` | `ACCOUNT_USAGE` | Total account-level credit consumption (compute + cloud services) | ~3 hours |
| `METERING_DAILY_HISTORY` | `ACCOUNT_USAGE` | Daily rollup of credits by service type | ~3 hours |
| `STORAGE_USAGE` | `ACCOUNT_USAGE` | Storage bytes (database, stage, failsafe) | ~24 hours |
| `DATABASE_STORAGE_USAGE_HISTORY` | `ACCOUNT_USAGE` | Per-database storage over time | ~24 hours |
| `TABLE_STORAGE_METRICS` | `ACCOUNT_USAGE` | Per-table active/time-travel/failsafe bytes | ~24 hours |
| `TAG_REFERENCES` | `ACCOUNT_USAGE` | Object tag assignments (for cost-by-tag) | Near real-time |
| `LOGIN_HISTORY` | `ACCOUNT_USAGE` | Auth events per user | ~2 hours |
| `WAREHOUSE_EVENTS_HISTORY` | `ACCOUNT_USAGE` | Suspend/resume/resize events | ~3 hours |
| `RATE_SHEET_DAILY` | `ORGANIZATION_USAGE` | Daily credit price (varies by contract) | ~24 hours |

### Access Requirements

```sql
USE ROLE ACCOUNTADMIN;

-- Grant ACCOUNT_USAGE access to the dashboard role
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE TRANSFORMER_ROLE;
-- Or create a dedicated monitoring role:
CREATE ROLE IF NOT EXISTS MONITOR_ROLE;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE MONITOR_ROLE;
GRANT ROLE MONITOR_ROLE TO ROLE TRANSFORMER_ROLE;
GRANT ROLE MONITOR_ROLE TO ROLE STREAMLIT_ROLE;
```

---

## 2. Tag Strategy for Cost Attribution

### 2.1 Create Cost Center Tags

```sql
USE ROLE SYSADMIN;

CREATE TAG IF NOT EXISTS AD_ANALYTICS.GOLD.COST_CENTER
    ALLOWED_VALUES 'etl', 'ingestion', 'bi', 'analytics', 'ad-hoc'
    COMMENT = 'Cost attribution for Snowflake resources';

CREATE TAG IF NOT EXISTS AD_ANALYTICS.GOLD.DEPARTMENT
    ALLOWED_VALUES 'data-engineering', 'business-intelligence', 'operations'
    COMMENT = 'Department-level cost attribution';

CREATE TAG IF NOT EXISTS AD_ANALYTICS.GOLD.PROJECT
    ALLOWED_VALUES 'ammodepot', 'streamlit-app'
    COMMENT = 'Project-level cost attribution';
```

### 2.2 Apply Tags to Warehouses

```sql
USE ROLE SYSADMIN;

-- ETL warehouse (dbt + Airbyte)
ALTER WAREHOUSE ETL_WH SET TAG
    AD_ANALYTICS.GOLD.COST_CENTER = 'etl',
    AD_ANALYTICS.GOLD.DEPARTMENT = 'data-engineering',
    AD_ANALYTICS.GOLD.PROJECT = 'ammodepot';

-- Legacy warehouse (pending suspension per OPTIMIZATION_PLAN Phase 3.3)
ALTER WAREHOUSE PC_FIVETRAN_WH SET TAG
    AD_ANALYTICS.GOLD.COST_CENTER = 'ingestion',
    AD_ANALYTICS.GOLD.DEPARTMENT = 'data-engineering',
    AD_ANALYTICS.GOLD.PROJECT = 'fivetran-legacy';

-- BI warehouse (used by Power BI — do NOT suspend/rename/drop)
ALTER WAREHOUSE COMPUTE_WH SET TAG
    AD_ANALYTICS.GOLD.COST_CENTER = 'bi',
    AD_ANALYTICS.GOLD.DEPARTMENT = 'business-intelligence',
    AD_ANALYTICS.GOLD.PROJECT = 'ammodepot';
```

### 2.3 Apply Tags to Users/Roles

```sql
USE ROLE SECURITYADMIN;

ALTER USER SVC_DBT SET TAG AD_ANALYTICS.GOLD.COST_CENTER = 'etl';
ALTER USER SVC_AIRBYTE SET TAG AD_ANALYTICS.GOLD.COST_CENTER = 'ingestion';
ALTER USER SVC_POWERBI SET TAG AD_ANALYTICS.GOLD.COST_CENTER = 'bi';
ALTER USER POWERBI_READER SET TAG AD_ANALYTICS.GOLD.COST_CENTER = 'bi';
```

---

## 3. dbt Models for Cost Monitoring

### 3.1 Proposed Model Structure

```
models/
└── gold/
    └── monitoring/
        ├── mon_warehouse_credits_daily.sql      # Daily credits per warehouse
        ├── mon_warehouse_utilization.sql         # Concurrency, idle time, efficiency
        ├── mon_query_cost_by_tag.sql             # Credits by query_tag / cost_center
        ├── mon_storage_daily.sql                 # Storage costs per database/table
        ├── mon_cost_anomalies.sql                # Day-over-day cost spikes
        └── _monitoring__models.yml               # Tests + docs
```

### 3.2 mon_warehouse_credits_daily.sql

```sql
-- Daily credit consumption per warehouse with dollar cost estimate
with warehouse_credits as (
    select
        date_trunc('day', start_time)                       as usage_date,
        warehouse_name,
        sum(credits_used)                                   as compute_credits,
        sum(credits_used_cloud_services)                    as cloud_services_credits,
        sum(credits_used) + sum(credits_used_cloud_services) as total_credits
    from snowflake.account_usage.warehouse_metering_history
    where start_time >= dateadd('day', -90, current_timestamp())
    group by 1, 2
),

-- Get credit price from rate sheet (falls back to $3.00 standard)
credit_price as (
    select
        coalesce(
            (select effective_rate
             from snowflake.organization_usage.rate_sheet_daily
             where usage_type = 'compute'
             qualify row_number() over (order by date desc) = 1),
            3.00
        ) as price_per_credit
)

select
    wc.usage_date                                           as USAGE_DATE,
    wc.warehouse_name                                       as WAREHOUSE_NAME,
    wc.compute_credits                                      as COMPUTE_CREDITS,
    wc.cloud_services_credits                               as CLOUD_SERVICES_CREDITS,
    wc.total_credits                                        as TOTAL_CREDITS,
    round(wc.total_credits * cp.price_per_credit, 2)        as ESTIMATED_COST_USD,
    -- Rolling averages for trend detection
    avg(wc.total_credits) over (
        partition by wc.warehouse_name
        order by wc.usage_date
        rows between 6 preceding and current row
    )                                                       as CREDITS_7D_AVG,
    avg(wc.total_credits) over (
        partition by wc.warehouse_name
        order by wc.usage_date
        rows between 29 preceding and current row
    )                                                       as CREDITS_30D_AVG
from warehouse_credits wc
cross join credit_price cp
order by wc.usage_date desc, wc.total_credits desc
```

### 3.3 mon_warehouse_utilization.sql

```sql
-- Warehouse utilization: concurrency, queuing, idle analysis
with load_data as (
    select
        date_trunc('hour', start_time)  as hour_ts,
        warehouse_name,
        avg(avg_running)                as avg_running_queries,
        avg(avg_queued_load)            as avg_queued_queries,
        avg(avg_blocked)                as avg_blocked_queries,
        max(avg_running)                as peak_running_queries
    from snowflake.account_usage.warehouse_load_history
    where start_time >= dateadd('day', -30, current_timestamp())
    group by 1, 2
),

events as (
    select
        date_trunc('day', timestamp)    as event_date,
        warehouse_name,
        count_if(event_name = 'RESUME_WAREHOUSE')  as resume_count,
        count_if(event_name = 'SUSPEND_WAREHOUSE') as suspend_count
    from snowflake.account_usage.warehouse_events_history
    where timestamp >= dateadd('day', -30, current_timestamp())
    group by 1, 2
),

daily_utilization as (
    select
        date_trunc('day', ld.hour_ts)   as usage_date,
        ld.warehouse_name,
        -- Active hours = hours where at least 1 query was running
        count_if(ld.avg_running_queries > 0)                    as active_hours,
        24 - count_if(ld.avg_running_queries > 0)               as idle_hours,
        round(count_if(ld.avg_running_queries > 0) / 24.0 * 100, 1) as utilization_pct,
        avg(ld.avg_running_queries)                              as avg_concurrency,
        max(ld.peak_running_queries)                             as peak_concurrency,
        sum(ld.avg_queued_queries)                               as total_queued,
        sum(ld.avg_blocked_queries)                              as total_blocked
    from load_data ld
    group by 1, 2
)

select
    du.usage_date                       as USAGE_DATE,
    du.warehouse_name                   as WAREHOUSE_NAME,
    du.active_hours                     as ACTIVE_HOURS,
    du.idle_hours                       as IDLE_HOURS,
    du.utilization_pct                  as UTILIZATION_PCT,
    du.avg_concurrency                  as AVG_CONCURRENCY,
    du.peak_concurrency                 as PEAK_CONCURRENCY,
    du.total_queued                     as TOTAL_QUEUED,
    du.total_blocked                    as TOTAL_BLOCKED,
    coalesce(ev.resume_count, 0)        as RESUME_COUNT,
    coalesce(ev.suspend_count, 0)       as SUSPEND_COUNT
from daily_utilization du
left join events ev
    on du.usage_date = ev.event_date
    and du.warehouse_name = ev.warehouse_name
order by du.usage_date desc
```

### 3.4 mon_query_cost_by_tag.sql

```sql
-- Cost attribution by query_tag, user, role, and warehouse
-- Leverages QUERY_TAG set on all service accounts per CLAUDE.md
with query_costs as (
    select
        date_trunc('day', start_time)                       as usage_date,
        warehouse_name,
        user_name,
        role_name,
        -- Parse query_tag for attribution
        coalesce(nullif(query_tag, ''), 'untagged')         as query_tag,
        -- Extract cost center from query_tag pattern (e.g., 'dbt:gold', 'airbyte:sync')
        case
            when query_tag ilike 'dbt%'     then 'dbt'
            when query_tag ilike 'airbyte%' then 'airbyte'
            when role_name = 'POWERBI_ROLE' then 'powerbi'
            when role_name = 'POWERBI_READONLY_ROLE' then 'powerbi'
            when role_name = 'STREAMLIT_ROLE' then 'streamlit'
            else 'other'
        end                                                  as cost_center,
        count(*)                                             as query_count,
        sum(total_elapsed_time) / 1000.0                     as total_elapsed_sec,
        avg(total_elapsed_time) / 1000.0                     as avg_elapsed_sec,
        sum(bytes_scanned)                                   as total_bytes_scanned,
        sum(credits_used_cloud_services)                     as cloud_services_credits,
        -- Approximate compute credits (proportional to execution time)
        -- True per-query credits not available — this is an allocation proxy
        sum(execution_time) / 1000.0 / 3600.0               as approx_compute_hours
    from snowflake.account_usage.query_history
    where start_time >= dateadd('day', -90, current_timestamp())
      and execution_status = 'SUCCESS'
      and warehouse_name is not null
    group by 1, 2, 3, 4, 5
)

select
    usage_date                                               as USAGE_DATE,
    warehouse_name                                           as WAREHOUSE_NAME,
    user_name                                                as USER_NAME,
    role_name                                                as ROLE_NAME,
    query_tag                                                as QUERY_TAG,
    cost_center                                              as COST_CENTER,
    query_count                                              as QUERY_COUNT,
    round(total_elapsed_sec, 1)                              as TOTAL_ELAPSED_SEC,
    round(avg_elapsed_sec, 2)                                as AVG_ELAPSED_SEC,
    round(total_bytes_scanned / power(1024, 3), 2)           as TOTAL_GB_SCANNED,
    round(cloud_services_credits, 4)                         as CLOUD_SERVICES_CREDITS,
    round(approx_compute_hours, 2)                           as APPROX_COMPUTE_HOURS
from query_costs
order by usage_date desc, approx_compute_hours desc
```

### 3.5 mon_storage_daily.sql

```sql
-- Storage costs by database (storage billed at ~$23/TB/month on-demand)
with storage as (
    select
        usage_date,
        database_name,
        average_database_bytes / power(1024, 4)             as active_tb,
        average_failsafe_bytes / power(1024, 4)             as failsafe_tb,
        (average_database_bytes + average_failsafe_bytes) / power(1024, 4) as total_tb
    from snowflake.account_usage.database_storage_usage_history
    where usage_date >= dateadd('day', -90, current_date())
),

stage_storage as (
    select
        usage_date,
        'STAGES' as database_name,
        average_stage_bytes / power(1024, 4)                as active_tb,
        0                                                   as failsafe_tb,
        average_stage_bytes / power(1024, 4)                as total_tb
    from snowflake.account_usage.storage_usage
    where usage_date >= dateadd('day', -90, current_date())
)

select
    usage_date                                               as USAGE_DATE,
    database_name                                            as DATABASE_NAME,
    round(active_tb, 6)                                      as ACTIVE_TB,
    round(failsafe_tb, 6)                                    as FAILSAFE_TB,
    round(total_tb, 6)                                       as TOTAL_TB,
    round(total_tb * 23.0, 2)                                as ESTIMATED_MONTHLY_COST_USD
from storage

union all

select
    usage_date, database_name, active_tb, failsafe_tb, total_tb,
    round(total_tb * 23.0, 2)
from stage_storage
order by usage_date desc, total_tb desc
```

### 3.6 mon_cost_anomalies.sql

```sql
-- Detect cost anomalies: days where credits exceed 2x the 7-day rolling average
with daily_credits as (
    select
        date_trunc('day', start_time)                       as usage_date,
        warehouse_name,
        sum(credits_used) + sum(credits_used_cloud_services) as total_credits
    from snowflake.account_usage.warehouse_metering_history
    where start_time >= dateadd('day', -90, current_timestamp())
    group by 1, 2
),

with_rolling as (
    select
        *,
        avg(total_credits) over (
            partition by warehouse_name
            order by usage_date
            rows between 7 preceding and 1 preceding
        ) as rolling_7d_avg,
        stddev(total_credits) over (
            partition by warehouse_name
            order by usage_date
            rows between 7 preceding and 1 preceding
        ) as rolling_7d_stddev
    from daily_credits
)

select
    usage_date                                               as USAGE_DATE,
    warehouse_name                                           as WAREHOUSE_NAME,
    round(total_credits, 4)                                  as TOTAL_CREDITS,
    round(rolling_7d_avg, 4)                                 as ROLLING_7D_AVG,
    round(rolling_7d_stddev, 4)                              as ROLLING_7D_STDDEV,
    round(total_credits / nullif(rolling_7d_avg, 0), 2)      as RATIO_VS_AVG,
    case
        when total_credits > rolling_7d_avg + 2 * coalesce(rolling_7d_stddev, 0) then 'SPIKE'
        when total_credits < rolling_7d_avg * 0.2 then 'DROP'
        else 'NORMAL'
    end                                                      as ANOMALY_STATUS
from with_rolling
where rolling_7d_avg is not null
order by usage_date desc
```

---

## 4. Key Standalone Queries (Ad-Hoc / Exploration)

### 4.1 Top 20 Most Expensive Queries (Last 30 Days)

```sql
USE ROLE ACCOUNTADMIN;

select
    query_id,
    query_text,
    warehouse_name,
    user_name,
    role_name,
    query_tag,
    execution_time / 1000                           as exec_sec,
    total_elapsed_time / 1000                       as elapsed_sec,
    bytes_scanned / power(1024, 3)                  as gb_scanned,
    partitions_scanned,
    partitions_total,
    round(partitions_scanned / nullif(partitions_total, 0) * 100, 1) as partition_scan_pct,
    credits_used_cloud_services
from snowflake.account_usage.query_history
where start_time >= dateadd('day', -30, current_timestamp())
  and execution_status = 'SUCCESS'
  and warehouse_name is not null
order by execution_time desc
limit 20;
```

### 4.2 Warehouse Auto-Suspend Effectiveness

```sql
USE ROLE ACCOUNTADMIN;

-- Shows how quickly warehouses suspend after last query
-- Use to tune AUTO_SUSPEND settings
with events as (
    select
        warehouse_name,
        event_name,
        timestamp,
        lead(timestamp) over (partition by warehouse_name order by timestamp) as next_event_ts,
        lead(event_name) over (partition by warehouse_name order by timestamp) as next_event
    from snowflake.account_usage.warehouse_events_history
    where timestamp >= dateadd('day', -7, current_timestamp())
      and event_name in ('RESUME_WAREHOUSE', 'SUSPEND_WAREHOUSE')
)
select
    warehouse_name,
    count_if(event_name = 'RESUME_WAREHOUSE')                               as resume_count,
    avg(case when event_name = 'RESUME_WAREHOUSE' and next_event = 'SUSPEND_WAREHOUSE'
             then datediff('second', timestamp, next_event_ts) end)          as avg_active_sec,
    min(case when event_name = 'RESUME_WAREHOUSE' and next_event = 'SUSPEND_WAREHOUSE'
             then datediff('second', timestamp, next_event_ts) end)          as min_active_sec,
    max(case when event_name = 'RESUME_WAREHOUSE' and next_event = 'SUSPEND_WAREHOUSE'
             then datediff('second', timestamp, next_event_ts) end)          as max_active_sec
from events
group by warehouse_name
order by resume_count desc;
```

### 4.3 Credit Consumption by Service Type

```sql
USE ROLE ACCOUNTADMIN;

-- Breakdown: compute vs cloud services vs serverless vs storage
select
    date_trunc('day', usage_date)       as usage_date,
    service_type,
    sum(credits_used)                   as credits
from snowflake.account_usage.metering_daily_history
where usage_date >= dateadd('day', -90, current_date())
group by 1, 2
order by 1 desc, 3 desc;
```

### 4.4 Idle Warehouse Detection

```sql
USE ROLE ACCOUNTADMIN;

-- Warehouses that burned credits with zero queries
select
    wm.warehouse_name,
    date_trunc('hour', wm.start_time) as hour_ts,
    wm.credits_used,
    coalesce(wl.avg_running, 0) as avg_running
from snowflake.account_usage.warehouse_metering_history wm
left join snowflake.account_usage.warehouse_load_history wl
    on wm.warehouse_name = wl.warehouse_name
    and date_trunc('hour', wm.start_time) = date_trunc('hour', wl.start_time)
where wm.start_time >= dateadd('day', -7, current_timestamp())
  and wm.credits_used > 0
  and coalesce(wl.avg_running, 0) = 0
order by wm.credits_used desc;
```

### 4.5 Cost by Tag (Warehouse-Level)

```sql
USE ROLE ACCOUNTADMIN;

-- Cost attribution via object tags applied to warehouses
select
    tr.tag_value                                    as cost_center,
    wm.warehouse_name,
    date_trunc('day', wm.start_time)                as usage_date,
    sum(wm.credits_used)                            as compute_credits,
    sum(wm.credits_used) * 3.00                     as estimated_cost_usd
from snowflake.account_usage.warehouse_metering_history wm
join snowflake.account_usage.tag_references tr
    on tr.object_name = wm.warehouse_name
    and tr.tag_name = 'COST_CENTER'
    and tr.domain = 'WAREHOUSE'
where wm.start_time >= dateadd('day', -30, current_timestamp())
group by 1, 2, 3
order by estimated_cost_usd desc;
```

---

## 5. Dashboard Layout — Streamlit Page

### 5.1 Proposed File

```
streamlit_app/pages/4_Snowflake_Costs.py
```

### 5.2 Page Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  SNOWFLAKE COST MONITOR                                   [30d]│
├────────────┬────────────┬────────────┬──────────────────────────┤
│ Total      │ Compute    │ Storage    │ Anomalies                │
│ Credits    │ Credits    │ Cost/Mo    │ (last 7d)                │
│ $X,XXX     │ XXX.X      │ $XX.XX     │ ⚠ 2 spikes              │
├────────────┴────────────┴────────────┴──────────────────────────┤
│                                                                 │
│  DAILY CREDIT TREND (stacked area by warehouse)                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ETL_WH               ││
│  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ PC_FIVETRAN_WH        ││
│  │▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ COMPUTE_WH             ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
├─────────────────────────────┬───────────────────────────────────┤
│ COST BY TAG / COST CENTER  │  WAREHOUSE UTILIZATION            │
│ ┌───────────────────────┐  │  ┌─────────────────────────────┐  │
│ │ etl        ████ $XXX  │  │  │ ETL_WH    ██████░░ 74%      │  │
│ │ ingestion  ██   $XX   │  │  │ FIVETRAN  █░░░░░░░ 12%      │  │
│ │ bi         █    $X    │  │  │ COMPUTE   ░░░░░░░░  3%      │  │
│ │ other      ░    $X    │  │  │                              │  │
│ └───────────────────────┘  │  └─────────────────────────────┘  │
│                             │                                   │
├─────────────────────────────┴───────────────────────────────────┤
│ COST ANOMALIES                                                  │
│ ┌───────────────────────────────────────────────────────────────┐│
│ │ 2026-03-21  ETL_WH      SPIKE  4.2x avg  12.3 credits       ││
│ │ 2026-03-18  COMPUTE_WH  SPIKE  2.8x avg   1.1 credits       ││
│ └───────────────────────────────────────────────────────────────┘│
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ TOP EXPENSIVE QUERIES (last 7d)                                │
│ ┌──────────┬──────────┬────────┬──────────┬────────────────────┐│
│ │ User     │ WH       │ Tag    │ Elapsed  │ GB Scanned         ││
│ ├──────────┼──────────┼────────┼──────────┼────────────────────┤│
│ │ SVC_DBT  │ ETL_WH   │ dbt:go │ 45.2s   │ 2.3 GB             ││
│ │ SVC_PBI  │ ETL_WH   │        │ 32.1s   │ 1.8 GB             ││
│ └──────────┴──────────┴────────┴──────────┴────────────────────┘│
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ STORAGE BREAKDOWN (treemap by database)                        │
│ ┌───────────────────────────────────────────────────────────────┐│
│ │ ┌─────────────────────┐┌──────────────┐┌─────────┐          ││
│ │ │   AD_AIRBYTE        ││ AD_ANALYTICS ││ STAGES  │          ││
│ │ │   XX.X TB           ││ X.X TB       ││ X.X TB  │          ││
│ │ └─────────────────────┘└──────────────┘└─────────┘          ││
│ └───────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### 5.3 Chart Types

| Section | Chart Type | Library | Notes |
|---|---|---|---|
| KPI cards | HTML/CSS | `st.markdown` | Match existing dark theme (`chart_theme.py`) |
| Daily credit trend | Stacked area | `go.Scatter(stackgroup)` | One trace per warehouse |
| Cost by tag | Horizontal bar | `go.Bar(orientation='h')` | Sorted by cost descending |
| Warehouse utilization | Bullet/bar | `go.Bar` | % of 24h active, colored by threshold |
| Anomalies | Dark HTML table | `dark_dataframe()` | Conditional row coloring for SPIKE/DROP |
| Top queries | Dark HTML table | `dark_dataframe()` | Truncated query text, sortable |
| Storage | Treemap | `go.Treemap` | Area proportional to TB |

### 5.4 Filters

- **Date range**: `st.selectbox` — 7d / 30d / 90d (default: 30d)
- **Warehouse**: `st.multiselect` — filter all charts
- **Cost center**: `st.selectbox` — filter by tag attribution

---

## 6. Alerting Thresholds

### 6.1 Snowflake Resource Monitors (Built-in)

```sql
USE ROLE ACCOUNTADMIN;

-- Account-level monthly budget monitor
CREATE OR REPLACE RESOURCE MONITOR MONTHLY_BUDGET
    WITH CREDIT_QUOTA = 500           -- Adjust to your monthly budget
    TRIGGERS
        ON 75 PERCENT DO NOTIFY       -- Email at 75%
        ON 90 PERCENT DO NOTIFY       -- Email at 90%
        ON 100 PERCENT DO SUSPEND;    -- Hard stop at 100%

ALTER ACCOUNT SET RESOURCE_MONITOR = MONTHLY_BUDGET;

-- Per-warehouse monitors
CREATE OR REPLACE RESOURCE MONITOR ETL_WH_MONITOR
    WITH CREDIT_QUOTA = 300
    TRIGGERS
        ON 80 PERCENT DO NOTIFY
        ON 100 PERCENT DO NOTIFY;     -- Don't suspend ETL — alert only

ALTER WAREHOUSE ETL_WH SET RESOURCE_MONITOR = ETL_WH_MONITOR;
```

### 6.2 Dashboard-Level Alerts (Streamlit)

Display warning banners in the dashboard when:

| Condition | Severity | Message |
|---|---|---|
| Daily credits > 2x 7-day avg | Warning | "Credit spike detected on {warehouse}" |
| Warehouse utilization < 10% for 7 consecutive days | Info | "{warehouse} underutilized — consider suspension" |
| `PC_FIVETRAN_WH` consuming credits | Error | "Legacy warehouse PC_FIVETRAN_WH is still active" |
| Monthly projected cost > budget | Warning | "On track to exceed monthly budget by {pct}%" |
| Queued queries > 0 for sustained period | Warning | "Query queuing detected on {warehouse} — consider resize" |

---

## 7. Best Practices for Snowflake Cost Optimization

### 7.1 Warehouse Tuning

| Setting | Current | Recommended | Rationale |
|---|---|---|---|
| `AUTO_SUSPEND` (ETL_WH) | 60s | 60s (keep) | Good — dbt runs every 10 min, 60s prevents constant resume |
| `AUTO_SUSPEND` (COMPUTE_WH) | Default | 300s (5 min) | BI queries are bursty — 5 min avoids resume thrashing |
| `AUTO_RESUME` | TRUE | TRUE (keep) | Required for scheduled workloads |
| `WAREHOUSE_SIZE` | XSMALL | XSMALL (keep) | 99 models in ~3 min is excellent on XSMALL |
| Multi-cluster | OFF | OFF (keep) | Single-user ETL workload, no concurrency benefit |
| `STATEMENT_TIMEOUT_IN_SECONDS` | Default (48h) | 1800 (30 min) | Prevent runaway queries from burning credits |

```sql
USE ROLE SYSADMIN;

ALTER WAREHOUSE ETL_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 1800;
ALTER WAREHOUSE COMPUTE_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 1800;
```

### 7.2 Query Optimization Checks

Run monthly to find optimization opportunities:

```sql
USE ROLE ACCOUNTADMIN;

-- Queries with poor partition pruning (scanning >80% of partitions)
select
    query_id,
    substr(query_text, 1, 200) as query_preview,
    warehouse_name,
    user_name,
    partitions_scanned,
    partitions_total,
    round(partitions_scanned / nullif(partitions_total, 0) * 100, 1) as scan_pct,
    bytes_scanned / power(1024, 3) as gb_scanned
from snowflake.account_usage.query_history
where start_time >= dateadd('day', -7, current_timestamp())
  and partitions_total > 100
  and partitions_scanned / nullif(partitions_total, 0) > 0.8
  and execution_status = 'SUCCESS'
order by partitions_scanned desc
limit 20;

-- Queries with excessive spillage (disk I/O from insufficient memory)
select
    query_id,
    substr(query_text, 1, 200) as query_preview,
    warehouse_name,
    bytes_spilled_to_local_storage / power(1024, 3) as gb_spilled_local,
    bytes_spilled_to_remote_storage / power(1024, 3) as gb_spilled_remote
from snowflake.account_usage.query_history
where start_time >= dateadd('day', -7, current_timestamp())
  and (bytes_spilled_to_local_storage > 0 or bytes_spilled_to_remote_storage > 0)
order by bytes_spilled_to_remote_storage desc
limit 20;
```

### 7.3 Storage Optimization

```sql
USE ROLE ACCOUNTADMIN;

-- Find tables with high time-travel cost (reduce retention if not needed)
select
    table_catalog,
    table_schema,
    table_name,
    active_bytes / power(1024, 3) as active_gb,
    time_travel_bytes / power(1024, 3) as time_travel_gb,
    failsafe_bytes / power(1024, 3) as failsafe_gb,
    retained_for_clone_bytes / power(1024, 3) as clone_gb
from snowflake.account_usage.table_storage_metrics
where active_bytes > 0
order by time_travel_bytes desc
limit 20;

-- Transient tables skip failsafe (Gold tables already use +transient: true — good)
-- Consider setting DATA_RETENTION_TIME_IN_DAYS = 1 for Silver tables
USE ROLE SYSADMIN;
ALTER SCHEMA AD_ANALYTICS.SILVER SET DATA_RETENTION_TIME_IN_DAYS = 1;
```

### 7.4 Cost Governance Checklist

- [ ] **Resource monitors** on account and per-warehouse
- [ ] **Tags** on all warehouses, users, databases
- [ ] **Statement timeout** set on all warehouses (prevent runaway queries)
- [ ] **Auto-suspend** tuned per workload pattern (60s for ETL, 300s for BI)
- [ ] **Legacy warehouses** suspended (`PC_FIVETRAN_WH`)
- [ ] **Query tags** on all service accounts (already done per CLAUDE.md)
- [ ] **Transient tables** for non-critical data (already done for Gold)
- [ ] **Time-travel retention** reduced for ephemeral/rebuildable data
- [ ] **Monthly review** of top expensive queries and idle warehouses
- [ ] **Budget alerts** at 75%, 90%, 100% of monthly credit allocation

---

## 8. Implementation Roadmap

| Step | Task | Effort | Dependency |
|---|---|---|---|
| 1 | Grant `IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE` to `TRANSFORMER_ROLE` | 5 min | Snowflake ACCOUNTADMIN |
| 2 | Create and apply cost center tags (Section 2) | 30 min | Step 1 |
| 3 | Create resource monitors (Section 6.1) | 15 min | ACCOUNTADMIN |
| 4 | Set `STATEMENT_TIMEOUT_IN_SECONDS` on all warehouses | 5 min | SYSADMIN |
| 5 | Build dbt monitoring models (Section 3) | 3-4 hours | Steps 1-2 |
| 6 | Add YAML tests for monitoring models | 1 hour | Step 5 |
| 7 | Build Streamlit page `4_Snowflake_Costs.py` | 4-6 hours | Steps 5-6 |
| 8 | Run optimization queries (Section 7.2-7.3) and act on findings | 2 hours | Step 1 |
| 9 | Suspend PC_FIVETRAN_WH (per OPTIMIZATION_PLAN Phase 3.3) | 15 min + 2-week soak | Step 8 |

**Total effort:** ~1.5-2 days
**Recurring:** Monthly review of dashboard + top query analysis (~1 hour)

---

## 9. dbt_project.yml Configuration

```yaml
# Add under models: ammodepot: gold:
models:
  ammodepot:
    gold:
      monitoring:
        +materialized: table
        +schema: gold
        +tags: ['monitoring']
        +query_tag: 'dbt:monitoring'
```

This keeps monitoring models in the Gold schema alongside existing consumption tables, materialized as tables for dashboard query performance.

---

## 10. Estimated Monthly Costs Being Monitored

Based on current setup from CLAUDE.md:

| Resource | Current Monthly | Notes |
|---|---|---|
| ETL_WH (XSMALL, dbt + Airbyte) | ~$50-80 | 10-min cycle, 60s auto-suspend |
| COMPUTE_WH (BI warehouse, Power BI) | ~$46 | Active — used by Power BI, do NOT suspend |
| PC_FIVETRAN_WH (legacy) | ~$540 | **Should be suspended** |
| Storage (AD_AIRBYTE + AD_ANALYTICS) | ~$5-15 | Depends on CDC volume |
| Cloud services | ~$5-10 | Usually free tier covers it |
| **Total current** | **~$650-690** | |
| **After PC_FIVETRAN_WH suspension** | **~$110-150** | **~$540/mo savings** |
