with daily_agg as (
    select
        s.created_at::date       as sale_date,
        p.caliber                as caliber,
        sum(s.qty_ordered)       as units_sold
    from {{ ref('f_sales') }} s
    join {{ ref('int_product_analyst') }} p
        on s.product_id = p.product_id
    where s.status in ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
        and p.caliber is not null
        and p.caliber != ''
    group by 1, 2
),

eligible_calibers as (
    select caliber
    from daily_agg
    group by caliber
    having count(distinct sale_date) >= 90
)

select d.sale_date, d.caliber, d.units_sold
from daily_agg d
join eligible_calibers e on d.caliber = e.caliber
