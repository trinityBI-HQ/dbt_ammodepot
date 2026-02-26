{% test assert_no_special_characters(model, column_name) %}

select *
from {{ model }}
where {{ column_name }} ~ '[^a-zA-Z0-9\s]'

{% endtest %}
