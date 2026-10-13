-- one row per scheme: returns, risk and rank inside its category
with latest as (
    select scheme_code, max(nav_date) as as_of
    from {{ ref('int_nav_clean') }}
    group by 1
),

points as (
    select
        l.scheme_code,
        l.as_of,
        n0.nav as nav_latest,
        n1.nav_date as date_1y, n1.nav as nav_1y,
        n3.nav_date as date_3y, n3.nav as nav_3y,
        n5.nav_date as date_5y, n5.nav as nav_5y
    from latest l
    join {{ ref('int_nav_clean') }} n0
      on n0.scheme_code = l.scheme_code and n0.nav_date = l.as_of
    {% for yrs in [1, 3, 5] %}
    left join lateral (
        select nav_date, nav
        from {{ ref('int_nav_clean') }} c
        where c.scheme_code = l.scheme_code
          and c.nav_date <= (l.as_of - interval '{{ yrs }} year')::date
          and c.nav_date >  (l.as_of - interval '{{ yrs }} year' - interval '10 day')::date
        order by c.nav_date desc
        limit 1
    ) n{{ yrs }} on true
    {% endfor %}
),

risk as (
    select
        c.scheme_code,
        stddev_samp(c.log_return) filter (where c.nav_date > (l.as_of - interval '1 year')::date)  * sqrt(252) as volatility_1y,
        stddev_samp(c.log_return) filter (where c.nav_date > (l.as_of - interval '3 year')::date)  * sqrt(252) as volatility_3y,
        stddev_samp(c.log_return) filter (where c.nav_date > (l.as_of - interval '3 year')::date and c.log_return < 0)
            * sqrt(252) as downside_vol_3y
    from {{ ref('int_nav_clean') }} c
    join latest l using (scheme_code)
    group by 1
),

drawdown as (
    select scheme_code, min(nav / running_max - 1) as max_drawdown_3y
    from (
        select
            c.scheme_code,
            c.nav,
            max(c.nav) over (partition by c.scheme_code order by c.nav_date) as running_max
        from {{ ref('int_nav_clean') }} c
        join latest l using (scheme_code)
        where c.nav_date >= (l.as_of - interval '3 year')::date
    ) x
    group by 1
),

metrics as (
    select
        p.scheme_code,
        p.as_of,
        p.nav_latest,
        (power(p.nav_latest / p.nav_1y, 365.0 / (p.as_of - p.date_1y)) - 1)::numeric as return_1y,
        (power(p.nav_latest / p.nav_3y, 365.0 / (p.as_of - p.date_3y)) - 1)::numeric as cagr_3y,
        (power(p.nav_latest / p.nav_5y, 365.0 / (p.as_of - p.date_5y)) - 1)::numeric as cagr_5y,
        r.volatility_1y::numeric   as volatility_1y,
        r.volatility_3y::numeric   as volatility_3y,
        r.downside_vol_3y::numeric as downside_vol_3y,
        d.max_drawdown_3y::numeric as max_drawdown_3y
    from points p
    left join risk r using (scheme_code)
    left join drawdown d using (scheme_code)
),

final as (
    select
        m.*,
        (m.cagr_3y - {{ var('risk_free_rate') }}) / nullif(m.volatility_3y, 0)    as sharpe_3y,
        (m.cagr_3y - {{ var('risk_free_rate') }}) / nullif(m.downside_vol_3y, 0)  as sortino_3y,
        s.scheme_name,
        s.fund_house,
        s.asset_class,
        s.sub_category,
        s.plan_type,
        m.as_of >= (select max(as_of) from latest) - 7 as is_active
    from metrics m
    join {{ ref('dim_scheme') }} s
      on s.scheme_code = m.scheme_code and s.is_current
)

select
    *,
    case when is_active and cagr_3y is not null then
        rank() over (partition by is_active and cagr_3y is not null, sub_category, plan_type
                     order by cagr_3y desc)
    end as rank_cagr_3y_in_category,
    case when is_active and sharpe_3y is not null then
        rank() over (partition by is_active and sharpe_3y is not null, sub_category, plan_type
                     order by sharpe_3y desc)
    end as rank_sharpe_3y_in_category,
    count(*) filter (where is_active and cagr_3y is not null)
        over (partition by sub_category, plan_type) as funds_in_category
from final
