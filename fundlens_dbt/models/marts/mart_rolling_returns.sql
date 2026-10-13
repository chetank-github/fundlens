-- month-end NAV per scheme with 1-year and 3-year rolling returns (for consistency charts)
with monthly as (
    select distinct on (scheme_code, date_trunc('month', nav_date))
        scheme_code,
        date_trunc('month', nav_date)::date as month,
        nav_date,
        nav
    from {{ ref('int_nav_clean') }}
    order by scheme_code, date_trunc('month', nav_date), nav_date desc
),

lagged as (
    select
        *,
        lag(nav, 12)   over w as nav_12m,
        lag(month, 12) over w as month_12m,
        lag(nav, 36)   over w as nav_36m,
        lag(month, 36) over w as month_36m
    from monthly
    window w as (partition by scheme_code order by month)
)

select
    l.scheme_code,
    l.month,
    l.nav_date,
    l.nav,
    case when l.month_12m = (l.month - interval '12 month')::date
         then l.nav / l.nav_12m - 1 end                     as rolling_1y_return,
    case when l.month_36m = (l.month - interval '36 month')::date
         then power(l.nav / l.nav_36m, 1.0 / 3) - 1 end     as rolling_3y_cagr,
    s.sub_category,
    s.plan_type
from lagged l
join {{ ref('dim_scheme') }} s
  on s.scheme_code = l.scheme_code and s.is_current
