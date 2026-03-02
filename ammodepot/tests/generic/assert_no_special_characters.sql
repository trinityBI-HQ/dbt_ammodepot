{% test assert_no_special_characters(model, column_name) %}

select *
from {{ model }}
where regexp_like({{ column_name }}, '[^a-zA-Z0-9\\s]')

{% endtest %}
