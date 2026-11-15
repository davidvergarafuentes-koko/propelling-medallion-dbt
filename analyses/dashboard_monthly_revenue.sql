-- Dashboard tile 1: Monthly revenue trend (line chart).
-- Business question: is revenue growing, flat or falling over time?
-- Grain: one row per month. Month comes from the ORDER date.
-- Filters: region, year. Chart: x = month_start, y = net_revenue.
with last_order as (

    -- Deliberately ignores the filters: the last month of data does not depend on what you select.
    select max(order_dates.calendar_date) as last_order_date
    from {{ ref('fct_sales') }} as sales
    inner join {{ ref('dim_date') }} as order_dates
        on sales.order_date_key = order_dates.date_key

)

select
    date_trunc('month', order_dates.calendar_date)                      as month_start,
    sum(sales.net_amount)                                               as net_revenue,
    sum(sales.margin_amount)                                            as margin,
    count(distinct sales.order_key)                                     as orders
from {{ ref('fct_sales') }} as sales
inner join {{ ref('dim_date') }} as order_dates
    on sales.order_date_key = order_dates.date_key
inner join {{ ref('dim_customer') }} as customers
    on sales.customer_sk = customers.customer_sk
cross join last_order
where {{ dashboard_filter('region') }}
  and {{ dashboard_filter('year') }}
  -- Orders stop part-way through the final month. Without this line the chart ends in a false collapse.
  and order_dates.calendar_date < date_trunc('month', dateadd('day', 1, last_order.last_order_date))
group by month_start
order by month_start
