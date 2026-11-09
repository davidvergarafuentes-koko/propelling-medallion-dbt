-- Grain: one row per part (product).
select
    {{ dbt_utils.generate_surrogate_key(['part_key']) }} as part_sk,
    part_key,
    part_name,
    manufacturer,
    brand,
    part_type,
    part_grade,
    part_finish,
    part_material,
    part_size,
    container,
    container_size,
    container_type,
    retail_price
from {{ ref('slv_tpch__part') }}
