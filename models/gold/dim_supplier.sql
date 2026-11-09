-- Grain: one row per supplier. Nation and region are flattened in, as on dim_customer.
select
    {{ dbt_utils.generate_surrogate_key(['supplier.supplier_key']) }} as supplier_sk,
    supplier.supplier_key,
    supplier.supplier_name,
    nation.nation_name    as supplier_nation,
    region.region_name    as supplier_region,
    supplier.account_balance
from {{ ref('slv_tpch__supplier') }} as supplier
inner join {{ ref('slv_tpch__nation') }} as nation
    on supplier.nation_key = nation.nation_key
inner join {{ ref('slv_tpch__region') }} as region
    on nation.region_key = region.region_key
