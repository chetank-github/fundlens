-- marks one-day spikes: a big jump that fully reverses the next day (bad data, not real moves)
{{ config(materialized='view') }}

with base as (
    select
        scheme_code,
        nav_date,
        nav,
        lag(nav)  over w as prev_nav,
        lead(nav) over w as next_nav
    from {{ ref('fct_nav_daily') }}
    window w as (partition by scheme_code order by nav_date)
)

select
    scheme_code,
    nav_date,
    nav,
    prev_nav,
    coalesce(
        abs(nav / prev_nav - 1) > {{ var('spike_threshold') }}
        and abs(next_nav / nav - 1) > {{ var('spike_threshold') }}
        and sign(nav / prev_nav - 1) <> sign(next_nav / nav - 1),
        false
    ) as is_spike
from base
