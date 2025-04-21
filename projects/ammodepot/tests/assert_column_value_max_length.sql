select *
from {{ model }}
where length({{ column_name }}) > {{ max_length }};