{% test assert_no_past_dates(model, column_name) %}

select *
from {{ model }}
where {{ column_name }} < current_date

{% endtest %}
