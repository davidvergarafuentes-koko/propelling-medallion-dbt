-- Grain: one row per world region.
-- Rules: readable names, Title Case labels, filler comment dropped.
select
    r_regionkey            as region_key,
    initcap(trim(r_name))  as region_name,
    _loaded_at
from {{ ref('brz_tpch__region') }}
