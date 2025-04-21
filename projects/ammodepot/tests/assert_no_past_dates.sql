select *
from {{ model }}
where {{ column_name }} < current_date;