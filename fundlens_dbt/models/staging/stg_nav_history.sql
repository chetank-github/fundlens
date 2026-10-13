select
    scheme_code,
    nav_date,
    nav,
    loaded_at
from {{ source('raw', 'nav_history') }}
where nav > 0
