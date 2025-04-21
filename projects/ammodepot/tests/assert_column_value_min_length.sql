select *
from {{ model }}
where length({{ column_name }}) < {{ min_length }};