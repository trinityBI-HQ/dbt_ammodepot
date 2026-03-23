{% test assert_date_range(model, column_name, start_date, end_date) %}

select *
from {{ model }}
where {{ column_name }} < '{{ start_date }}' or {{ column_name }} > '{{ end_date }}'

{% endtest %}
