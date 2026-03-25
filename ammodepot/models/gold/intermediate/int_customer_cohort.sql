select
    rank_id,
    min(date_trunc('month', created_at)) as cohort_month
from {{ ref('f_sales') }}
group by rank_id
