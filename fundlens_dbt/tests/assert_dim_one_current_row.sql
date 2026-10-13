select scheme_code, count(*)
from {{ ref('dim_scheme') }}
where is_current
group by 1
having count(*) <> 1