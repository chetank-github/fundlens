select scheme_code, nav_date, count(*)
from {{ ref('fct_nav_daily') }}
group by 1, 2
having count(*) > 1