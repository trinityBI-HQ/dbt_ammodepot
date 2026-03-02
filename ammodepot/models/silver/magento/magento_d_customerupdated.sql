with cleaned_emails as (
    select
        lower(coalesce(nullif(customer_email, ''), 'customer@nonidentified.com')) as customer_email
    from {{ source('magento', 'sales_order') }}
),

distinct_emails as (
    select distinct customer_email
    from cleaned_emails
)

select
    customer_email,
    row_number() over (order by customer_email) as rank_id
from distinct_emails
