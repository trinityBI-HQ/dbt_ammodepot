{% test assert_valid_date_format(model, column_name) %}

select *
from {{ model }}
where try_cast({{ column_name }} as date) is null

{% endtest %}
