-- Grain: one row per customer.
-- Rules: readable names, addresses trimmed (profiling found stray spaces), segment in Title Case.
select
    c_custkey                     as customer_key,
    trim(c_name)                  as customer_name,
    trim(c_address)               as customer_address,
    c_nationkey                   as nation_key,
    trim(c_phone)                 as customer_phone,
    c_acctbal                     as account_balance,
    initcap(trim(c_mktsegment))   as market_segment,
    _loaded_at
from {{ ref('brz_tpch__customer') }}
