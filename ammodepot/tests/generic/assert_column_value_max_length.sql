{% test assert_column_value_max_length(model, column_name, max_length) %}

select *
from {{ model }}
where length({{ column_name }}) > {{ max_length }}

{% endtest %}
