-- Dashboard tile 2: Revenue and margin by region (bar chart).
-- Business question: which regions bring in the most revenue, and how profitable is it?
-- Grain: one row per customer region. A sale belongs to the region of the customer who bought.
-- Filters: region, year. Chart: x = customer_region, y = net_revenue.
select
    customers.customer_region,
    sum(sales.net_amount)                                               as net_revenue,
    sum(sales.margin_amount)                                            as margin,
    -- Ratio of two totals. Averaging each line's percentage would give small lines too much weight.
    round(100 * sum(sales.margin_amount) / nullif(sum(sales.net_amount), 0), 2) as margin_pct,
    count(distinct sales.order_key)                                     as orders
from {{ ref('fct_sales') }} as sales
inner join {{ ref('dim_customer') }} as customers
    on sales.customer_sk = customers.customer_sk
inner join {{ ref('dim_date') }} as order_dates
    on sales.order_date_key = order_dates.date_key
where {{ dashboard_filter('region') }}
  and {{ dashboard_filter('year') }}
group by customers.customer_region
order by net_revenue desc
