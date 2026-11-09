{#
  By default dbt builds custom schemas as <target_schema>_<custom_schema> (e.g. DEV_BRONZE).
  We override it so that:
    - dev / prod  -> exactly BRONZE, SILVER, GOLD (what the challenge asks for)
    - ci          -> <ci_schema>_BRONZE, ... so every pull request builds in isolation
                     and never overwrites the shared layers.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'ci' -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
