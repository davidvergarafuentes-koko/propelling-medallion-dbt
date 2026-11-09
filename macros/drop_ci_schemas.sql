{#
  Removes the schemas a CI run created, so test tables do not pile up and cost storage.
  Run with: dbt run-operation drop_ci_schemas --target ci
  It refuses any other target, so it can never touch BRONZE, SILVER or GOLD.
#}
{% macro drop_ci_schemas() %}
    {% if target.name != 'ci' %}
        {{ exceptions.raise_compiler_error("drop_ci_schemas only runs on the ci target, not '" ~ target.name ~ "'.") }}
    {% endif %}

    {% for layer in ['bronze', 'silver', 'gold'] %}
        {% set schema_name = target.schema ~ '_' ~ layer %}
        {% do run_query('drop schema if exists ' ~ target.database ~ '.' ~ schema_name) %}
        {% do log('Dropped ' ~ target.database ~ '.' ~ schema_name, info=true) %}
    {% endfor %}
{% endmacro %}
