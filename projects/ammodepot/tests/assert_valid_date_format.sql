select *
from {{ model }}
where try_cast({{ column_name }} as date) is null;