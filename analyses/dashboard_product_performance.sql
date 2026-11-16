-- Dashboard tile 5: Revenue and margin by product material (bar chart).
-- Business question: which kinds of product bring in the most revenue, and how profitable are they?
-- Grain: one row per part material (the last word of the part type, e.g. Copper or Steel).
-- Filters: region (of the customer), year (of the ORDER). Chart: x = net_revenue, y = part_material.
select
    parts.part_material,
    sum(sales.net_amount)                                               as net_revenue,
    sum(sales.margin_amount)                                            as margin,
    round(100 * sum(sales.margin_amount) / nullif(sum(sales.net_amount), 0), 2) as margin_pct,
    sum(sales.quantity)                                                 as units_sold,
    count(distinct sales.part_sk)                                       as parts_sold
from {{ ref('fct_sales') }} as sales
inner join {{ ref('dim_part') }} as parts
    on sales.part_sk = parts.part_sk
inner join {{ ref('dim_customer') }} as customers
    on sales.customer_sk = customers.customer_sk
inner join {{ ref('dim_date') }} as order_dates
    on sales.order_date_key = order_dates.date_key
where {{ dashboard_filter('region') }}
  and {{ dashboard_filter('year') }}
group by parts.part_material
order by net_revenue desc
