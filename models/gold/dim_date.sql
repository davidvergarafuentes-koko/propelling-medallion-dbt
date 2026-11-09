-- Grain: one row per calendar day, from the first order to the last delivery in the data.
-- The fact table joins here four times: order, ship, promised and receipt date.
with spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('1992-01-01' as date)",
        end_date="cast('1999-01-01' as date)"
    ) }}

)

select
    {{ date_to_key('date_day') }}                   as date_key,
    date_day::date                                  as calendar_date,
    year(date_day)                                  as year_number,
    quarter(date_day)                               as quarter_number,
    year(date_day) || '-Q' || quarter(date_day)     as year_quarter,
    month(date_day)                                 as month_number,
    to_char(date_day, 'MON')                        as month_name,
    to_char(date_day, 'YYYY-MM')                    as year_month,
    weekiso(date_day)                               as iso_week_number,
    day(date_day)                                   as day_of_month,
    dayofweekiso(date_day)                          as day_of_week_number,
    dayname(date_day)                               as day_name,
    dayofweekiso(date_day) in (6, 7)                as is_weekend
from spine
