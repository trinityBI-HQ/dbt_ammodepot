select *
from {{ model }}
where {{ updated_at_column }} < (current_date - interval '{{ interval_days }} days');