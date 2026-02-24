with

-- 0. Customer base: rank_id ↔ email
customer_base as (
  select
    rank_id,
    customer_email
  from {{ ref('magento_d_customerupdated') }}
),

-- 1. Total purchases all time
total_purchases as (
    select 
        cb.rank_id,
        COUNT(distinct fs.order_id) as total_purchases_all_time
    from {{ ref('f_sales') }}           as fs
    inner join customer_base                 as cb 
      on fs.customer_email = cb.customer_email
    where fs.status in ({{ var('ammodepot_valid_order_statuses') }})
    group by cb.rank_id
),

-- 2. Sales in the last 12 months (up to end of prior month)
customer_sales as (
    select 
        cb.rank_id,
        COUNT(distinct fs.order_id)                   as number_of_purchases,
        SUM(fs.row_total)                             as total_revenue,
        case 
          when SUM(fs.row_total) = 0 
          then null 
          else (SUM(fs.row_total) - SUM(fs.cost))::DOUBLE PRECISION 
               / SUM(fs.row_total)
        end                                           as margin,
        DATEDIFF(
          day,
          MAX(fs.created_at),
          DATEADD(
            day, -1,
            DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','{{ var("ammodepot_timezone") }}',CURRENT_DATE))
          )
        )                                             as days_since_last_purchase
    from {{ ref('f_sales') }}           as fs
    inner join customer_base                 as cb 
      on fs.customer_email = cb.customer_email
    where
      fs.created_at >= DATEADD(
        year, -1,
        DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','{{ var("ammodepot_timezone") }}',CURRENT_DATE))
      )
      and fs.created_at < DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','{{ var("ammodepot_timezone") }}',CURRENT_DATE))
      and fs.status in ({{ var('ammodepot_valid_order_statuses') }})
    group by cb.rank_id
),

-- 3. Assemble base customer + metrics
d_customerupdatesview as (
    select 
        cb.rank_id,
        cb.customer_email,
        cs.number_of_purchases,
        cs.total_revenue,
        cs.margin,
        cs.days_since_last_purchase,
        tp.total_purchases_all_time,

        -- Frequency label & int
        case 
          when cs.number_of_purchases = 1   then 'F1'
          when cs.number_of_purchases <= 2  then 'F2'
          when cs.number_of_purchases <= 3  then 'F3'
          when cs.number_of_purchases <= 5  then 'F4'
          when cs.number_of_purchases >= 5  then 'F5'
          else 'F0'
        end                                as frequency,
        case 
          when cs.number_of_purchases = 1   then 1
          when cs.number_of_purchases <= 2  then 2
          when cs.number_of_purchases <= 3  then 3
          when cs.number_of_purchases <= 5  then 4
          when cs.number_of_purchases >= 5  then 5
          else 0
        end                                as frequency_int,

        -- Recency label & int
        case 
          when cs.days_since_last_purchase <= 30 then 'R5'
          when cs.days_since_last_purchase <= 60 then 'R4'
          when cs.days_since_last_purchase <= 180 then 'R3'
          when cs.days_since_last_purchase <= 240 then 'R2'
          when cs.days_since_last_purchase <= 365 then 'R1'
          else 'R0'
        end                                as recency,
        case 
          when cs.days_since_last_purchase <= 30 then 5
          when cs.days_since_last_purchase <= 60 then 4
          when cs.days_since_last_purchase <= 120 then 3
          when cs.days_since_last_purchase <= 180 then 2
          when cs.days_since_last_purchase <= 365 then 1
          else 0
        end                                as recency_int,

        -- Value label & int
        case 
          when cs.total_revenue < 149   then 'V1'
          when cs.total_revenue <= 225  then 'V2'
          when cs.total_revenue <= 300  then 'V3'
          when cs.total_revenue <= 500  then 'V4'
          when cs.total_revenue > 500   then 'V5'
          else 'V0'
        end                                as value,
        case 
          when cs.total_revenue < 149   then 1
          when cs.total_revenue <= 225  then 2
          when cs.total_revenue <= 300  then 3
          when cs.total_revenue <= 500  then 4
          when cs.total_revenue > 500   then 5
          else 0
        end                                as value_int,

        -- Margin classification & int
        case 
          when cs.margin < 0.20         then 'M1'
          when cs.margin < 0.24         then 'M2'
          when cs.margin < 0.26         then 'M3'
          when cs.margin < 0.30         then 'M4'
          when cs.margin >= 0.30        then 'M5'
          else 'M0'
        end                                as margin_classification,
        case 
          when cs.margin < 0.20         then 1
          when cs.margin < 0.24         then 2
          when cs.margin < 0.26         then 3
          when cs.margin < 0.30         then 4
          when cs.margin >= 0.30        then 5
          else 0
        end                                as margin_int
    from customer_base               as cb
    left join customer_sales        as cs on cb.rank_id = cs.rank_id
    left join total_purchases       as tp on cb.rank_id = tp.rank_id
),

-- 4. RFM + Monetary Value segmentation
Segmentation as (
    select 
        dv.*,

        case
          when FLOOR((dv.margin_int + dv.value_int)/2) = 1 then 'MV1'
          when FLOOR((dv.margin_int + dv.value_int)/2) = 2 then 'MV2'
          when FLOOR((dv.margin_int + dv.value_int)/2) = 3 then 'MV3'
          when FLOOR((dv.margin_int + dv.value_int)/2) = 4 then 'MV4'
          when FLOOR((dv.margin_int + dv.value_int)/2) = 5 then 'MV5'
          else 'MV0'
        end                                as monetary_value,

        case
          when dv.frequency = 'F5' and dv.recency = 'R5' then 'Super Engaged'
          when dv.frequency = 'F4' and dv.recency = 'R5' then 'Highly Engaged'
          when dv.frequency = 'F5' and dv.recency = 'R4' then 'Active Loyalist'
          when dv.frequency = 'F4' and dv.recency = 'R4' then 'Engaged Regular'
          when dv.frequency = 'F3' and dv.recency in ('R4','R5') then 'Regular w/Potential'
          when dv.frequency in ('F4','F5') and dv.recency = 'R3' then 'At-Risk Regular'
          when dv.frequency = 'F3' and dv.recency = 'R3' then 'Moderate Engager'
          when dv.frequency in ('F1','F2') and dv.recency = 'R4' then 'Relatively New Buyer'
          when dv.frequency = 'F1' and dv.recency = 'R5' then 'New Buyer'
          when dv.frequency = 'F2' and dv.recency = 'R5' then 'New Active Buyer'
          when dv.frequency in ('F2','F3') and dv.recency in ('R1','R2') then 'Lapsed Buyer'
          when dv.frequency = 'F1' and dv.recency = 'R1' then 'Inactive'
          when dv.frequency in ('F4','F5') and dv.recency = 'R1' then 'Lost Buyer'
          when dv.frequency = 'F1' and dv.recency in ('R2','R3') then 'Losing 1-Time Buyer'
          when dv.frequency = 'F2' and dv.recency = 'R3' then 'Nurture Potential'
          when dv.frequency in ('F4','F5') and dv.recency = 'R2' then 'Inactive Regular'
          else 'Unclassified'
        end                                as customer_classification
    from d_customerupdatesview       as dv
),

-- 5. Hard-coded customer groups via UNION ALL
customer_group_cte as (
    select 4 as customer_group_id, 'Law Enforcement'  as customer_group_code
    union all
    select 2,                   'Wholesale'
    union all
    select 1,                   'General'
    union all
    select 0,                   'NOT LOGGED IN'
    union all
    select 3,                   'Retailer'
),

-- 6. Customer-entity join to pick up group_id
customer_entity_cte as (
    select 
      email           as customer_email,
      group_id        as customer_group_id
    from {{ source('magento','customer_entity') }}
)

-- Final join & filter
select
    s.customer_email                  as CUSTOMER_EMAIL,
    s.rank_id                         as RANK_ID,
    s.number_of_purchases             as NUMBER_OF_PURCHASES,
    s.total_revenue                   as TOTAL_REVENUE,
    s.margin                          as MARGIN,
    s.days_since_last_purchase        as DAYS_SINCE_LAST_PURCHASE,
    s.total_purchases_all_time        as TOTAL_PURCHASES_ALL_TIME,
    s.frequency                       as FREQUENCY,
    s.frequency_int                   as FREQUENCY_INT,
    s.recency                         as RECENCY,
    s.recency_int                     as RECENCY_INT,
    s.value                           as VALUE,
    s.value_int                       as VALUE_INT,
    s.margin_classification           as MARGIN_CLASSIFICATION,
    s.margin_int                      as MARGIN_INT,
    s.monetary_value                  as MONETARY_VALUE,
    s.customer_classification         as CUSTOMER_CLASSIFICATION,
    COALESCE(cg.customer_group_code, 'Not Registered') as CUSTOMER_GROUP
from Segmentation            as s
left join customer_entity_cte as ce 
  on s.customer_email = ce.customer_email
left join customer_group_cte  as cg 
  on ce.customer_group_id = cg.customer_group_id
where s.customer_classification <> ''
