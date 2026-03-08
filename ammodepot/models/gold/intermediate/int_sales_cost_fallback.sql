-- Cost fallback: for each product, compute the average unit cost from
-- the most recent order date where cost > 0.  Used by f_sales to fill
-- in missing cost values on newer rows.
--
-- Replicates the exact same transformations as f_sales skubase/to_transfer/last
-- to ensure cost fallback values match the inline logic.
with interaction_base as (
    select
        {{ convert_tz('UTC', var("ammodepot_timezone"), 'cast(z.item_created_at as timestamp)') }}
                                                            as created_at,
        z.product_id,
        z.order_id,
        z.quantity_ordered,
        z.row_total
        - coalesce(z.amount_refunded, 0)
        - coalesce(z.discount_amount, 0)
        + coalesce(z.discount_refunded, 0)                  as row_total,
        z.order_item_id                                      as id,
        z.product_type,
        z.parent_item_id,
        coalesce(
          c.cost_unique,
          c.cost_duplicate,
          c.cost_avg,
          c.averageweightedcost_unique * z.quantity_ordered,
          c.averageweightedcost_duplicate * z.quantity_ordered,
          c.averageweightedcost_avg * z.quantity_ordered
        )                                                   as raw_cost
    from {{ ref('magento_sales_order_item') }}        as z
    left join {{ ref('int_fishbowl_order_cost') }}     as c  on z.order_item_id = c.order_item_id
),

-- Apply same transformations as skubase in f_sales
skubase as (
    select
        ib.product_id,
        ib.created_at                                        as timedate,
        ib.id                                                as order_item_id,
        case when ib.row_total = 0 then 0
             else ib.quantity_ordered
        end                                                  as qty_ordered,
        case when ib.quantity_ordered > 0 then ib.raw_cost
             else null
        end                                                  as cost,
        ib.product_type,
        ib.parent_item_id
    from interaction_base as ib
),

-- Configurable products transfer cost + qty to their simple children
to_transfer as (
    select
        order_item_id as id,
        cost,
        qty_ordered
    from skubase
    where product_type = 'configurable'
),

-- Resolve: simple products inherit from configurable parent when present.
-- Includes ALL product types (matching old f_sales behavior) so that
-- configurable product_ids contribute fallback cost for their children.
resolved as (
    select
        z.product_id,
        z.timedate,
        case when ty.id is not null then ty.cost else z.cost end           as cost,
        case when ty.id is not null then ty.qty_ordered else z.qty_ordered end as qty_ordered
    from skubase as z
    left join to_transfer as ty
      on ty.id = z.parent_item_id
),

-- Find the most recent date per product where cost > 0
last_day_cost as (
    select
        product_id,
        max(timedate) as last_scheduled_date
    from resolved
    where cost > 0
      and qty_ordered > 0
    group by product_id
),

-- Gather all rows on that date for the product
filtered_cost_prep as (
    select
        r.product_id,
        r.cost,
        r.qty_ordered as qty
    from resolved as r
    inner join last_day_cost as ld
      on     r.product_id = ld.product_id
         and r.timedate   = ld.last_scheduled_date
    where r.cost > 0
      and r.qty_ordered > 0
)

select
    product_id,
    sum(cost) / nullif(sum(qty), 0) as fallback_unit_cost
from filtered_cost_prep
group by product_id
