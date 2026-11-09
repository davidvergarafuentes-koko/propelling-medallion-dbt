-- Grain: one row per nation.
-- Region is kept as a key: joining it in is a dimensional modelling choice, so it belongs in Gold.
select
    n_nationkey            as nation_key,
    initcap(trim(n_name))  as nation_name,
    n_regionkey            as region_key,
    _loaded_at
from {{ ref('brz_tpch__nation') }}
