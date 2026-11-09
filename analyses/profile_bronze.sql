-- Data profile of Bronze: the evidence behind the rules in Silver.
-- Each row is one check. Run with: dbt show --select profile_bronze --limit 50
with lineitem as (select * from {{ ref('brz_tpch__lineitem') }}),
     orders   as (select * from {{ ref('brz_tpch__orders') }}),
     customer as (select * from {{ ref('brz_tpch__customer') }}),
     supplier as (select * from {{ ref('brz_tpch__supplier') }}),
     partsupp as (select * from {{ ref('brz_tpch__partsupp') }}),

line_totals as (
    select l_orderkey, sum(l_extendedprice * (1 - l_discount) * (1 + l_tax)) as line_total
    from lineitem
    group by l_orderkey
)

select 'lineitem: rows' as check_name, count(*)::varchar as result from lineitem
union all select 'lineitem: duplicate order and line keys', (count(*) - count(distinct l_orderkey, l_linenumber))::varchar from lineitem
union all select 'lineitem: quantities with fractions', count_if(l_quantity <> floor(l_quantity))::varchar from lineitem
union all select 'lineitem: quantity range', min(l_quantity) || ' to ' || max(l_quantity) from lineitem
union all select 'lineitem: discount range', min(l_discount) || ' to ' || max(l_discount) from lineitem
union all select 'lineitem: tax range', min(l_tax) || ' to ' || max(l_tax) from lineitem
union all select 'lineitem: shipped after received', count_if(l_shipdate > l_receiptdate)::varchar from lineitem
union all select 'lineitem: received after promised', count_if(l_receiptdate > l_commitdate)::varchar from lineitem
union all select 'lineitem: no matching part supplier', count(*)::varchar
    from lineitem as l
    left join partsupp as p on l.l_partkey = p.ps_partkey and l.l_suppkey = p.ps_suppkey
    where p.ps_partkey is null
union all select 'orders: date range', min(o_orderdate) || ' to ' || max(o_orderdate) from orders
union all select 'orders: distinct o_shippriority', count(distinct o_shippriority)::varchar from orders
union all select 'orders: largest gap between header and lines', max(abs(o.o_totalprice - t.line_total))::varchar
    from orders as o
    join line_totals as t on o.o_orderkey = t.l_orderkey
union all select 'customer: customers who ever ordered', count(distinct o_custkey)::varchar from orders
union all select 'customer: addresses with stray spaces', count_if(c_address <> trim(c_address))::varchar from customer
union all select 'customer: negative balances', count_if(c_acctbal < 0)::varchar from customer
union all select 'supplier: addresses with stray spaces', count_if(s_address <> trim(s_address))::varchar from supplier
