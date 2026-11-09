-- Grain: one row per customer, including customers who never ordered.
-- Nation and region are flattened in here: a star schema answers "by region" with one join.
with customers_with_orders as (

    select distinct customer_key
    from {{ ref('slv_tpch__orders') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['customer.customer_key']) }} as customer_sk,
    customer.customer_key,
    customer.customer_name,
    customer.market_segment,
    nation.nation_name                         as customer_nation,
    region.region_name                         as customer_region,
    customer.account_balance,
    customer.account_balance < 0               as has_negative_balance,
    ordered.customer_key is not null           as has_ordered
from {{ ref('slv_tpch__customer') }} as customer
inner join {{ ref('slv_tpch__nation') }} as nation
    on customer.nation_key = nation.nation_key
inner join {{ ref('slv_tpch__region') }} as region
    on nation.region_key = region.region_key
left join customers_with_orders as ordered
    on customer.customer_key = ordered.customer_key
