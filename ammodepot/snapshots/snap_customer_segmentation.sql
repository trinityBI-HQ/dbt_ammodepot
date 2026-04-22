{% snapshot snap_customer_segmentation %}

{{
    config(
        target_schema='gold',
        unique_key='customer_email',
        strategy='check',
        check_cols=[
            'customer_classification',
            'frequency',
            'recency',
            'value',
            'margin_classification',
        ],
        invalidate_hard_deletes=true,
    )
}}

select
    rank_id,
    customer_email,
    customer_classification,
    frequency,
    recency,
    value,
    margin_classification,
    monetary_value,
    number_of_purchases,
    total_revenue,
    days_since_last_purchase,
    customer_group
from {{ ref('d_customer_segmentation') }}

{% endsnapshot %}
