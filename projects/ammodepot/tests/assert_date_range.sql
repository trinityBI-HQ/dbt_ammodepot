select *
from {{ model }}
where {{ column_name }} < '{{ start_date }}' or {{ column_name }} > '{{ end_date }}';