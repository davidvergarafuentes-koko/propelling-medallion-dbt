-- Custom generic test: the total of this column must equal the total of a column in another table.
-- Returns one row when the totals differ, so zero rows means the test passes.
--   to:        the model or source to compare with
--   field:     the column to sum there, when its name differs from this column
--   tolerance: the largest difference allowed, in the column's own units
{% test column_total_matches(model, column_name, to, field=none, tolerance=0) %}

with this_model as (

    select sum({{ column_name }}) as this_total
    from {{ model }}

),

other_model as (

    select sum({{ field or column_name }}) as other_total
    from {{ to }}

)

select
    this_total,
    other_total,
    this_total - other_total as difference
from this_model
cross join other_model
where abs(coalesce(this_total, 0) - coalesce(other_total, 0)) > {{ tolerance }}

{% endtest %}
