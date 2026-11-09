-- Grain: one row per supplier.
-- Rules: readable names, addresses trimmed (profiling found stray spaces).
select
    s_suppkey          as supplier_key,
    trim(s_name)       as supplier_name,
    trim(s_address)    as supplier_address,
    s_nationkey        as nation_key,
    trim(s_phone)      as supplier_phone,
    s_acctbal          as account_balance,
    _loaded_at
from {{ ref('brz_tpch__supplier') }}
