-- Grain: one row per combination of low-cardinality sale descriptors that actually occurs.
-- This is a junk dimension: it keeps text labels out of the 6-million-row fact table.
select distinct
    sale_attributes_sk,
    order_status,
    order_priority_rank,
    order_priority,
    ship_mode,
    ship_instruction,
    return_status,
    line_status
from {{ ref('int_sales__order_lines') }}
