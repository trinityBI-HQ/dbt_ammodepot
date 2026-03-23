{% test assert_column_match_regex(model, column_name, regex_pattern) %}

select *
from {{ model }}
where {{ column_name }} !~ '{{ regex_pattern }}'

{% endtest %}
