-- Dashboard tile 4: Late delivery rate by ship mode (bar chart).
-- Business question: which shipping methods break our delivery promises most often?
-- Grain: one row per ship mode. A line is late when it was received after the promised date.
-- Filters: region (of the customer), year (of the ORDER). Chart: x = ship_mode, y = late_rate_pct.
select
    attributes.ship_mode,
    count(*)                                                            as order_lines,
    sum(sales.late_line_count)                                          as late_lines,
    -- late_line_count is 1 or 0, so its average is the share of lines that were late.
    round(100 * avg(sales.late_line_count), 2)                          as late_rate_pct,
    round(avg(sales.transit_days), 2)                                   as avg_transit_days
from {{ ref('fct_sales') }} as sales
inner join {{ ref('dim_sale_attributes') }} as attributes
    on sales.sale_attributes_sk = attributes.sale_attributes_sk
inner join {{ ref('dim_customer') }} as customers
    on sales.customer_sk = customers.customer_sk
inner join {{ ref('dim_date') }} as order_dates
    on sales.order_date_key = order_dates.date_key
where {{ dashboard_filter('region') }}
  and {{ dashboard_filter('year') }}
group by attributes.ship_mode
order by late_rate_pct desc
