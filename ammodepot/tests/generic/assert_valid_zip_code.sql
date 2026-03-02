{% test assert_valid_zip_code(model, column_name) %}

select *
from {{ model }}
where not regexp_like({{ column_name }}, '^[0-9]{5}-?[0-9]{3}$')

{% endtest %}
