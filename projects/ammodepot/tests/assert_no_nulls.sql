select *
from {{ model }}
where {{ column_name }} is null;