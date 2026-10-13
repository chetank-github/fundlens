-- data quality report: one row per problem found in the NAV data
with spikes as (
    select scheme_code, nav_date, 'spike_removed' as issue,
           'NAV ' || nav || ' vs previous ' || prev_nav as detail
    from {{ ref('int_nav_flagged') }}
    where is_spike
),

gaps as (
    select scheme_code, nav_date, 'gap_over_10_days' as issue,
           (nav_date - prev_date) || ' days since previous NAV' as detail
    from {{ ref('int_nav_clean') }}
    where nav_date - prev_date > 10
),

stale as (
    select scheme_code, nav_date, 'stale_nav_5_days' as issue,
           'NAV ' || nav || ' unchanged for 5 records' as detail
    from (
        select *,
               count(*) filter (where daily_return = 0)
                   over (partition by scheme_code order by nav_date rows 3 preceding) as zero_days
        from {{ ref('int_nav_clean') }}
    ) x
    where zero_days = 4
),

big_moves as (
    select scheme_code, nav_date, 'big_move_kept' as issue,
           'daily return ' || round(daily_return * 100, 1) || '%' as detail
    from {{ ref('int_nav_clean') }}
    where abs(daily_return) > {{ var('spike_threshold') }}
),

stopped as (
    select scheme_code, max(nav_date) as nav_date, 'stopped_reporting' as issue,
           'last NAV more than 7 days before the latest date' as detail
    from {{ ref('int_nav_clean') }}
    group by 1
    having max(nav_date) < (select max(nav_date) from {{ ref('int_nav_clean') }}) - 7
)

select * from spikes
union all select * from gaps
union all select * from stale
union all select * from big_moves
union all select * from stopped
