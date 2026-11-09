{#
  Bronze ingestion pattern, reused by every Bronze model.
  Copies a source table AS-IS (same columns, same names, same types, no filtering)
  and only appends audit metadata so every row can be traced back to its origin and load.
#}
{% macro ingest_raw(source_name, table_name) %}
select
    src.*,
    '{{ source(source_name, table_name) }}'      as _source_relation,
    '{{ invocation_id }}'                         as _dbt_invocation_id,
    current_timestamp()::timestamp_ntz            as _loaded_at
from {{ source(source_name, table_name) }} as src
{% endmacro %}
