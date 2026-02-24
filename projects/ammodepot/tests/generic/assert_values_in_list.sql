{% test assert_values_in_list(model, column_name, values_list) %}

select *
from {{ model }}
where {{ column_name }} not in ({{ values_list }})

{% endtest %}
