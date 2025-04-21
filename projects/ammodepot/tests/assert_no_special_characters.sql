select *
from {{ model }}
where {{ column_name }} ~ '[^a-zA-Z0-9\s]';