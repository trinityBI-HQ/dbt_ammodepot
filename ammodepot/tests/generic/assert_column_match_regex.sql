{% test assert_column_match_regex(model, column_name, regex_pattern) %}

select *
from {{ model }}
where not regexp_like({{ column_name }}, '{{ regex_pattern }}')

{% endtest %}
