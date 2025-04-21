select child.*
from {{ model }} as child
left join {{ ref('parent_model') }} as parent
on child.{{ column_name }} = parent.{{ parent_column }}
where parent.{{ parent_column }} is null;