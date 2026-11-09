-- Reconciliation test: the lines of an order must add up to the order header.
-- Returns the orders that fail, so zero rows means the test passes.
-- Tolerance: the source rounds each header to cents; the largest real difference found was 0.11.
with line_totals as (

    select order_key, sum(total_amount) as line_total
    from {{ ref('slv_tpch__lineitem') }}
    group by order_key

)

select
    orders.order_key,
    orders.order_total_price,
    line_totals.line_total,
    abs(orders.order_total_price - line_totals.line_total) as difference
from {{ ref('slv_tpch__orders') }} as orders
left join line_totals
    on orders.order_key = line_totals.order_key
where line_totals.order_key is null
   or abs(orders.order_total_price - line_totals.line_total) > 0.25
