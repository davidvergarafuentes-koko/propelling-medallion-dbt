-- Dashboard tile 3: Top 10 customers by net revenue (table).
-- Business question: which accounts matter most, and are they profitable?
-- Grain: one row per customer, keeping the 10 highest.
-- Filters: region, year. The ranking is recalculated for whatever is selected.
select
    customers.customer_name,
    customers.customer_nation,
    customers.customer_region,
    customers.market_segment,
    sum(sales.net_amount)                                              as net_revenue,
    sum(sales.margin_amount)                                            as margin,
    round(100 * sum(sales.margin_amount) / nullif(sum(sales.net_amount), 0), 2) as margin_pct,
    -- The fact table has one row per line, so a plain count would count lines rather than orders.
    count(distinct sales.order_key)                                     as orders
from {{ ref('fct_sales') }} as sales
inner join {{ ref('dim_customer') }} as customers
    on sales.customer_sk = customers.customer_sk
inner join {{ ref('dim_date') }} as order_dates
    on sales.order_date_key = order_dates.date_key
where {{ dashboard_filter('region') }}
  and {{ dashboard_filter('year') }}
group by
    customers.customer_key,
    customers.customer_name,
    customers.customer_nation,
    customers.customer_region,
    customers.market_segment
-- Keeps the 10 highest. customer_key breaks ties, so the same 10 customers appear on every run.
-- QUALIFY rather than LIMIT: dbt show adds its own LIMIT, and two in one query is a syntax error.
qualify row_number() over (order by sum(sales.net_amount) desc, customers.customer_key) <= 10
order by net_revenue desc, customers.customer_key
