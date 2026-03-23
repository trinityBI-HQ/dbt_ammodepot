{% test assert_column_value_min_length(model, column_name, min_length) %}

select *
from {{ model }}
where length({{ column_name }}) < {{ min_length }}

{% endtest %}
