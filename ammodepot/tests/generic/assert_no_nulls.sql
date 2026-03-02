{% test assert_no_nulls(model, column_name) %}

select *
from {{ model }}
where {{ column_name }} is null

{% endtest %}
