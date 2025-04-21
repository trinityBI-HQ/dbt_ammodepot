select *
from {{ model }}
where {{ column_name }} not in ({{ values_list }});