-- Grain: one row per part and supplier combination.
-- Rules: readable names only. supply_cost is what makes margin calculable in slv_tpch__lineitem.
select
    ps_partkey      as part_key,
    ps_suppkey      as supplier_key,
    ps_availqty     as available_quantity,
    ps_supplycost   as supply_cost,
    _loaded_at
from {{ ref('brz_tpch__partsupp') }}
