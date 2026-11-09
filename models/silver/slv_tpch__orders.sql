-- Grain: one row per order.
-- Rules: letter codes decoded; '1-URGENT' split into a sortable rank and a label;
-- o_shippriority dropped because it is 0 on every row.
-- An unmapped code becomes 'Unknown', which the accepted_values test then reports.
select
    o_orderkey                                             as order_key,
    o_custkey                                              as customer_key,
    o_orderdate                                            as order_date,
    o_orderstatus                                          as order_status_code,
    case o_orderstatus
        when 'F' then 'Fulfilled'
        when 'O' then 'Open'
        when 'P' then 'Partial'
        else 'Unknown'
    end                                                    as order_status,
    split_part(o_orderpriority, '-', 1)::integer           as order_priority_rank,
    initcap(split_part(o_orderpriority, '-', 2))           as order_priority,
    o_totalprice                                           as order_total_price,
    trim(o_clerk)                                          as clerk_name,
    _loaded_at
from {{ ref('brz_tpch__orders') }}
