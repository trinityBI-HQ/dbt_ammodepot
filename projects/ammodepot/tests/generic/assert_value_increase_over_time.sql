{% test assert_value_increase_over_time(model, column_name, date_column) %}

select *
from (
    select
        {{ column_name }},
        lag({{ column_name }}) over (order by {{ date_column }}) as previous_value
    from {{ model }}
) sub
where {{ column_name }} < previous_value

{% endtest %}
