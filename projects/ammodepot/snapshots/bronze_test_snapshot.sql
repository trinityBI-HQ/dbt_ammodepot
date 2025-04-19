{% snapshot bronze_test_snapshot %}
{{ config(
    target_schema='bronze',
    unique_key='id',
    strategy='check',
    check_cols=['amount','created_at']
) }}

select
  id,
  user_id,
  cast(amount as numeric)      as amount,
  cast(created_at as timestamp) as created_at
from {{ source('bronze','bronze_test') }}

{% endsnapshot %}
