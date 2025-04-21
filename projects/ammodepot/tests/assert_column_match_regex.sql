select *
from {{ model }}
where {{ column_name }} !~ '{{ regex_pattern }}';