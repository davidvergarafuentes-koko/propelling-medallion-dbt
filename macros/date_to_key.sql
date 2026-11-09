{#
  Turns a date into the integer key used by dim_date, e.g. 1994-01-20 -> 19940120.
  Used for dim_date and for each of the four dates on fct_sales, so they always match.
#}
{% macro date_to_key(date_column) -%}
    to_number(to_char({{ date_column }}, 'YYYYMMDD'))
{%- endmacro %}
