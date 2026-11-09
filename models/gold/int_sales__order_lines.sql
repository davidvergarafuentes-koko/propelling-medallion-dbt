{{ config(materialized='ephemeral') }}

-- Shared preparation step for Gold; it is not a table anyone queries.
-- Gives each order line its order header and its attribute key, so that
-- fct_sales and dim_sale_attributes are guaranteed to generate the same key.
select
    line.*,
    orders.customer_key,
    orders.order_date,
    orders.order_status,
    orders.order_priority_rank,
    orders.order_priority,
    {{ dbt_utils.generate_surrogate_key([
        'orders.order_status',
        'orders.order_priority_rank',
        'orders.order_priority',
        'line.ship_mode',
        'line.ship_instruction',
        'line.return_status',
        'line.line_status'
    ]) }} as sale_attributes_sk
from {{ ref('slv_tpch__lineitem') }} as line
inner join {{ ref('slv_tpch__orders') }} as orders
    on line.order_key = orders.order_key
