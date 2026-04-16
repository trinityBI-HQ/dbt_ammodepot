select
    created_at::date                                                    as sale_date,
    sum(row_total)                                                      as daily_revenue,
    count(distinct order_id)                                            as daily_orders,
    round(
        (sum(row_total) - sum(cost)) / nullif(sum(row_total), 0) * 100,
        2
    )                                                                   as daily_margin_pct
from {{ ref('f_sales') }}
where status in ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
group by 1
having sum(row_total) > 0
