with cleaned_emails as (
    select
        LOWER(COALESCE(NULLIF(CUSTOMER_EMAIL, ''), 'customer@nonidentified.com')) as CUSTOMER_EMAIL
    from {{ source('magento', 'sales_order') }}
),

distinct_emails as (
    select distinct CUSTOMER_EMAIL
    from cleaned_emails
)

select 
    CUSTOMER_EMAIL,
    ROW_NUMBER() over (order by CUSTOMER_EMAIL) as RANK_ID
from distinct_emails
