-- Grain: one row per part.
-- Rules: readable names; the compound type and container strings are split so each piece can be filtered.
-- Example: 'STANDARD ANODIZED STEEL' -> grade Standard, finish Anodized, material Steel.
-- Example: 'SM BAG' -> container size SM, container type BAG.
select
    p_partkey                             as part_key,
    trim(p_name)                          as part_name,
    trim(p_mfgr)                          as manufacturer,
    trim(p_brand)                         as brand,
    initcap(trim(p_type))                 as part_type,
    initcap(split_part(p_type, ' ', 1))   as part_grade,
    initcap(split_part(p_type, ' ', 2))   as part_finish,
    initcap(split_part(p_type, ' ', 3))   as part_material,
    p_size                                as part_size,
    trim(p_container)                     as container,
    split_part(p_container, ' ', 1)       as container_size,
    split_part(p_container, ' ', 2)       as container_type,
    p_retailprice                         as retail_price,
    _loaded_at
from {{ ref('brz_tpch__part') }}
