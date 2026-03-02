with customer_cohort as (
    select
        rank_id,
        min(date_trunc('month', created_at)) as cohort_month
    from {{ ref('f_sales') }}
    group by rank_id
),

monthly_orders as (
    select
        o.rank_id,
        c.cohort_month,
        date_trunc('month', o.created_at) as order_month,
        datediff(month, c.cohort_month, o.created_at) as month_number
    from {{ ref('f_sales') }} as o
    inner join customer_cohort as c on o.rank_id = c.rank_id
)

select
    cohort_month                                                    as COHORT_MONTH,
    month_number                                                    as MONTH_NUMBER,
    count(distinct rank_id)                                         as PURCHASERS,
    count(distinct case when month_number = 0 then rank_id end)     as COHORT_SIZE
from monthly_orders
group by cohort_month, month_number
