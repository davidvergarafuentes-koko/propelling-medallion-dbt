-- Reconciliation test: Gold must hold exactly the rows and money that Silver holds.
-- A join that duplicated or lost rows would change these totals.
-- Returns a row only when something differs, so zero rows means the test passes.
with silver as (

    select count(*) as line_count, sum(net_amount) as net, sum(margin_amount) as margin
    from {{ ref('slv_tpch__lineitem') }}

),

gold as (

    select count(*) as line_count, sum(net_amount) as net, sum(margin_amount) as margin
    from {{ ref('fct_sales') }}

)

select silver.*, gold.line_count as gold_line_count, gold.net as gold_net, gold.margin as gold_margin
from silver
cross join gold
where silver.line_count <> gold.line_count
   or silver.net <> gold.net
   or silver.margin <> gold.margin
