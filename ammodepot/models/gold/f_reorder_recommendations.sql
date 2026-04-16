with forecast_upper as (
    select
        caliber,
        sum(upper_bound)         as demand_upper_30d,
        avg(predicted_units)     as daily_avg_predicted
    from ad_analytics.gold.f_forecast
    where forecast_type = 'caliber'
      and forecast_date > current_date()
      and forecast_date <= dateadd('day', 30, current_date())
    group by caliber
),

inventory_by_caliber as (
    select
        p.caliber,
        sum(coalesce(i.qty_available, 0)) as qty_available,
        sum(coalesce(i.qty_on_order, 0))  as qty_on_order
    from {{ ref('f_inventoryview') }} as i
    inner join {{ ref('int_product_analyst') }} as p
        on i.part_number = p.sku
    where p.caliber is not null
      and p.caliber != ''
    group by p.caliber
),

vendor_agg as (
    select
        p.caliber,
        po.vendor_id,
        round(avg(po.precise_leadtime), 0) as avg_lead_time,
        avg(po.unit_cost)                  as avg_unit_cost
    from {{ ref('f_pos') }} as po
    inner join {{ ref('int_product_analyst') }} as p
        on po.part_number = p.sku
    where po.precise_leadtime is not null
      and po.vendor_id is not null
      and p.caliber is not null
      and p.caliber != ''
    group by p.caliber, po.vendor_id
),

best_vendor as (
    select caliber, vendor_id, avg_lead_time, avg_unit_cost
    from vendor_agg
    qualify row_number() over (
        partition by caliber
        order by avg_lead_time asc nulls last
    ) = 1
),

reorder_calc as (
    select
        f.caliber,
        coalesce(i.qty_available, 0)              as qty_available,
        coalesce(i.qty_on_order, 0)               as qty_on_order,
        round(f.demand_upper_30d, 0)              as demand_upper_30d,
        round(f.daily_avg_predicted, 1)           as daily_avg_predicted,
        greatest(0,
            round(f.demand_upper_30d, 0)
            - coalesce(i.qty_available, 0)
            - coalesce(i.qty_on_order, 0)
        )                                         as reorder_qty,
        coalesce(bv.avg_lead_time, 14)            as lead_time_days,
        bv.vendor_id                              as recommended_vendor_id,
        coalesce(bv.avg_unit_cost, 0)             as avg_unit_cost,
        case
            when f.daily_avg_predicted > 0
            then round(
                coalesce(i.qty_available, 0) / f.daily_avg_predicted,
                1
            )
            else null
        end                                       as days_of_supply,
        case
            when f.daily_avg_predicted > 0
            then dateadd(
                'day',
                greatest(
                    round(
                        coalesce(i.qty_available, 0) / f.daily_avg_predicted
                    ) - coalesce(bv.avg_lead_time, 14),
                    0
                )::int,
                current_date()
            )
            else null
        end                                       as reorder_by
    from forecast_upper as f
    left join inventory_by_caliber as i on f.caliber = i.caliber
    left join best_vendor as bv on f.caliber = bv.caliber
),

final as (
    select
        rc.caliber                                as CALIBER,
        rc.qty_available                          as QTY_AVAILABLE,
        rc.qty_on_order                           as QTY_ON_ORDER,
        rc.demand_upper_30d                       as DEMAND_UPPER_30D,
        rc.daily_avg_predicted                    as DAILY_AVG_PREDICTED,
        rc.reorder_qty                            as REORDER_QTY,
        rc.lead_time_days                         as LEAD_TIME_DAYS,
        rc.days_of_supply                         as DAYS_OF_SUPPLY,
        rc.reorder_by                             as REORDER_BY,
        case
            when rc.days_of_supply <= rc.lead_time_days
                then 'Critical'
            when rc.days_of_supply <= rc.lead_time_days * 2
                then 'Warning'
            when rc.days_of_supply > 90
                then 'Overstock'
            else 'OK'
        end                                       as URGENCY,
        rc.recommended_vendor_id                  as RECOMMENDED_VENDOR_ID,
        dv.vendor_name                            as RECOMMENDED_VENDOR,
        rc.avg_unit_cost                          as AVG_UNIT_COST,
        case
            when rc.reorder_qty > 0
            then round(rc.reorder_qty * rc.avg_unit_cost, 2)
            else 0
        end                                       as ESTIMATED_ORDER_COST,
        current_timestamp()                       as REFRESHED_AT
    from reorder_calc as rc
    left join {{ ref('d_vendor') }} as dv
        on rc.recommended_vendor_id = dv.vendor_id
)

select * from final
