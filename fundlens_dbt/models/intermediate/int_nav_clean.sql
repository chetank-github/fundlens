-- clean NAV series (spikes removed) with daily returns
{{ config(indexes=[{'columns': ['scheme_code', 'nav_date'], 'unique': True}]) }}

with clean as (
    select scheme_code, nav_date, nav
    from {{ ref('int_nav_flagged') }}
    where not is_spike
)

select
    scheme_code,
    nav_date,
    nav,
    lag(nav_date) over w                as prev_date,
    nav / lag(nav) over w - 1           as daily_return,
    ln(nav / lag(nav) over w)           as log_return
from clean
window w as (partition by scheme_code order by nav_date)
