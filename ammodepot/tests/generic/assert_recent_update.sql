{% test assert_recent_update(model, column_name, interval_days) %}

select *
from {{ model }}
where {{ column_name }} < dateadd(day, -{{ interval_days }}, current_date)

{% endtest %}
