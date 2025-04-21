select *
from {{ model }}
where {{ column_name }} !~ '^[0-9]{5}-?[0-9]{3}$';