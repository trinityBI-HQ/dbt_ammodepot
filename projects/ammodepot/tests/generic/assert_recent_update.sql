{% test assert_recent_update(model, column_name, interval_days) %}

select *
from {{ model }}
where {{ column_name }} < (current_date - interval '{{ interval_days }} days')

{% endtest %}
