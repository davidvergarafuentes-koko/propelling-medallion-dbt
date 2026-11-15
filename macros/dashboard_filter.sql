{#
  Lets one query file serve both dbt and a Snowflake Dashboard.

  Snowflake Dashboards fill in a filter through the placeholder {{ filter('region') }}.
  That looks like Jinja, so dbt would try to run it and fail. This macro writes it out as plain text.

    dbt show --select dashboard_top_customers
        filter_name becomes: true (no filter, so dbt can run the query to test it)

    dbt compile --select dashboard_top_customers --vars 'snowsight: true'
        filter_name becomes: the placeholder (paste the compiled SQL into the dashboard tile)
#}
{% macro dashboard_filter(filter_name) -%}
    {%- if var('snowsight', false) -%}
        {{ "{{ filter('" ~ filter_name ~ "') }}" }}
    {%- else -%}
        true
    {%- endif -%}
{%- endmacro %}
