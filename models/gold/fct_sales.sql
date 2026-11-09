-- Grain: one row per order line.
-- Holds only keys and measures, so all descriptive text lives in the dimensions.
select
    {{ dbt_utils.generate_surrogate_key(['order_key', 'line_number']) }} as sales_sk,

    -- Degenerate dimension: identifies the order, with no table of its own.
    order_key,
    line_number,

    -- Keys to the dimensions. Hashing the same value as the dimension gives the same key, with no join.
    {{ dbt_utils.generate_surrogate_key(['customer_key']) }}  as customer_sk,
    {{ dbt_utils.generate_surrogate_key(['part_key']) }}      as part_sk,
    {{ dbt_utils.generate_surrogate_key(['supplier_key']) }}  as supplier_sk,
    sale_attributes_sk,
    {{ date_to_key('order_date') }}    as order_date_key,
    {{ date_to_key('ship_date') }}     as ship_date_key,
    {{ date_to_key('commit_date') }}   as commit_date_key,
    {{ date_to_key('receipt_date') }}  as receipt_date_key,

    -- Additive measures: safe to SUM across any dimension.
    quantity,
    gross_amount,
    discount_amount,
    net_amount,
    tax_amount,
    total_amount,
    cost_amount,
    margin_amount,
    iff(is_late, 1, 0)      as late_line_count,
    iff(is_returned, 1, 0)  as returned_line_count,

    -- Non-additive: use AVG, or group by them. Never SUM.
    discount_rate,
    tax_rate,
    transit_days,
    days_late
from {{ ref('int_sales__order_lines') }}
