-- Dashboard tile 6: Top 10 suppliers by net revenue (bar chart).
-- Business question: which suppliers do we depend on most?
-- Grain: one row per supplier, keeping the 10 highest.
-- Filters: region (of the CUSTOMER who bought, not of the supplier), year (of the ORDER).
select
    suppliers.supplier_name,
    suppliers.supplier_nation,
    suppliers.supplier_region,
    sum(sales.net_amount)                                               as net_revenue,
    sum(sales.margin_amount)                                            as margin,
    round(100 * sum(sales.margin_amount) / nullif(sum(sales.net_amount), 0), 2) as margin_pct,
    count(*)                                                            as order_lines
from {{ ref('fct_sales') }} as sales
inner join {{ ref('dim_supplier') }} as suppliers
    on sales.supplier_sk = suppliers.supplier_sk
inner join {{ ref('dim_customer') }} as customers
    on sales.customer_sk = customers.customer_sk
inner join {{ ref('dim_date') }} as order_dates
    on sales.order_date_key = order_dates.date_key
where {{ dashboard_filter('region') }}
  and {{ dashboard_filter('year') }}
group by
    suppliers.supplier_key,
    suppliers.supplier_name,
    suppliers.supplier_nation,
    suppliers.supplier_region
-- supplier_key breaks ties, so the same 10 suppliers appear on every run.
-- QUALIFY rather than LIMIT: dbt show adds its own LIMIT, and two in one query is a syntax error.
qualify row_number() over (order by sum(sales.net_amount) desc, suppliers.supplier_key) <= 10
order by net_revenue desc, suppliers.supplier_key
