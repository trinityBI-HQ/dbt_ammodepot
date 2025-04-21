select *
from {{ model }}
where {{ column_name }} not like '%_@__%.__%';