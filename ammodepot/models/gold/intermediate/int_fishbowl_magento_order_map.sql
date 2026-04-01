with fishbowl_orders as (
    select
        sales_order_id,
        split_part(sales_order_number, '-', 1) as order_number_base
    from {{ ref('fishbowl_so') }}
),

magento_orders as (
    select
        order_id,
        order_increment_id
    from {{ ref('magento_sales_order') }}
)

select
    fb.sales_order_id as fishbowl_so_id,
    mg.order_id       as magento_order_id
from fishbowl_orders as fb
inner join magento_orders as mg
    on fb.order_number_base = cast(mg.order_increment_id as varchar)
