-- Grain: one row per order line (order_key + line_number).
-- This is the single definition of every money measure, so Gold and BI never recalculate them.

with lineitem as (

    select * from {{ ref('brz_tpch__lineitem') }}

),

supply_cost as (

    select part_key, supplier_key, supply_cost
    from {{ ref('slv_tpch__partsupp') }}

),

renamed as (

    select
        l_orderkey            as order_key,
        l_linenumber          as line_number,
        l_partkey             as part_key,
        l_suppkey             as supplier_key,
        l_quantity::integer   as quantity,
        l_extendedprice       as gross_amount,
        l_discount            as discount_rate,
        l_tax                 as tax_rate,
        l_returnflag          as return_flag_code,
        case l_returnflag
            when 'R' then 'Returned'
            when 'A' then 'Accepted'
            when 'N' then 'Not Yet Received'
            else 'Unknown'
        end                   as return_status,
        l_linestatus          as line_status_code,
        case l_linestatus
            when 'O' then 'Open'
            when 'F' then 'Fulfilled'
            else 'Unknown'
        end                   as line_status,
        l_shipdate            as ship_date,
        l_commitdate          as commit_date,
        l_receiptdate         as receipt_date,
        -- Left as delivered: Title Case would corrupt values such as FOB and COD.
        trim(l_shipmode)      as ship_mode,
        trim(l_shipinstruct)  as ship_instruction,
        _loaded_at
    from lineitem

),

priced as (

    select
        renamed.*,
        cost.supply_cost,
        (gross_amount * discount_rate)::number(18, 4)                  as discount_amount,
        (gross_amount * (1 - discount_rate))::number(18, 4)            as net_amount,
        (gross_amount * (1 - discount_rate) * tax_rate)::number(18, 4) as tax_amount,
        (quantity * cost.supply_cost)::number(18, 4)                   as cost_amount
    from renamed
    -- Left join: a line with no supplier offer stays visible and fails the not_null test on supply_cost.
    left join supply_cost as cost
        on  renamed.part_key = cost.part_key
        and renamed.supplier_key = cost.supplier_key

),

final as (

    select
        order_key,
        line_number,
        part_key,
        supplier_key,
        quantity,
        discount_rate,
        tax_rate,
        supply_cost,
        gross_amount,
        discount_amount,
        net_amount,
        tax_amount,
        net_amount + tax_amount                 as total_amount,
        cost_amount,
        net_amount - cost_amount                as margin_amount,
        return_flag_code,
        return_status,
        return_flag_code = 'R'                  as is_returned,
        line_status_code,
        line_status,
        ship_date,
        commit_date,
        receipt_date,
        datediff('day', ship_date, receipt_date)   as transit_days,
        datediff('day', commit_date, receipt_date) as days_late,
        receipt_date > commit_date              as is_late,
        ship_mode,
        ship_instruction,
        _loaded_at
    from priced

)

select * from final
