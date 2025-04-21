select *
from {{ model }}
where {{ column_name }} < 0;