with

customer_base as (
  select
    rank_id,
    customer_email
  from {{ ref('magento_d_customerupdated') }}
),

total_purchases as (
    select
        cb.rank_id,
        count(distinct fs.order_id) as total_purchases_all_time
    from {{ ref('f_sales') }}           as fs
    inner join customer_base                 as cb
      on fs.customer_email = cb.customer_email
    where fs.status in ({{ var('ammodepot_valid_order_statuses') }})
    group by cb.rank_id
),

customer_sales as (
    select
        cb.rank_id,
        count(distinct fs.order_id)                   as number_of_purchases,
        sum(fs.row_total)                             as total_revenue,
        case
          when sum(fs.row_total) = 0
          then null
          else cast((sum(fs.row_total) - sum(fs.cost)) as float)
               / sum(fs.row_total)
        end                                           as margin,
        datediff(
          day,
          max(fs.created_at),
          dateadd(
            day, -1,
            date_trunc('month', convert_timezone('UTC','{{ var("ammodepot_timezone") }}',current_date))
          )
        )                                             as days_since_last_purchase
    from {{ ref('f_sales') }}           as fs
    inner join customer_base                 as cb
      on fs.customer_email = cb.customer_email
    where
      fs.created_at >= dateadd(
        year, -1,
        date_trunc('month', convert_timezone('UTC','{{ var("ammodepot_timezone") }}',current_date))
      )
      and fs.created_at < date_trunc('month', convert_timezone('UTC','{{ var("ammodepot_timezone") }}',current_date))
      and fs.status in ({{ var('ammodepot_valid_order_statuses') }})
    group by cb.rank_id
),

d_customerupdatesview as (
    select
        cb.rank_id,
        cb.customer_email,
        cs.number_of_purchases,
        cs.total_revenue,
        cs.margin,
        cs.days_since_last_purchase,
        tp.total_purchases_all_time,

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

segmentation as (
    select
        dv.rank_id,
        dv.customer_email,
        dv.number_of_purchases,
        dv.total_revenue,
        dv.margin,
        dv.days_since_last_purchase,
        dv.total_purchases_all_time,
        dv.frequency,
        dv.frequency_int,
        dv.recency,
        dv.recency_int,
        dv.value,
        dv.value_int,
        dv.margin_classification,
        dv.margin_int,

        case
          when floor((dv.margin_int + dv.value_int)/2) = 1 then 'MV1'
          when floor((dv.margin_int + dv.value_int)/2) = 2 then 'MV2'
          when floor((dv.margin_int + dv.value_int)/2) = 3 then 'MV3'
          when floor((dv.margin_int + dv.value_int)/2) = 4 then 'MV4'
          when floor((dv.margin_int + dv.value_int)/2) = 5 then 'MV5'
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

customer_entity_cte as (
    select
      email           as customer_email,
      customer_group_id
    from {{ ref('magento_customer_entity') }}
)

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
    coalesce(cg.customer_group_code, 'Not Registered') as CUSTOMER_GROUP
from segmentation            as s
left join customer_entity_cte as ce
  on s.customer_email = ce.customer_email
left join customer_group_cte  as cg
  on ce.customer_group_id = cg.customer_group_id
where s.customer_classification <> ''
