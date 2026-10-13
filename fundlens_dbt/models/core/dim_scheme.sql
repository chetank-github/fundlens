-- one row per scheme per version (SCD2). is_current = latest version.
select
    s.dbt_scd_id                       as scheme_sk,
    s.scheme_code,
    s.scheme_name,
    s.fund_house,
    s.scheme_category,
    s.asset_class,
    s.sub_category,
    s.plan_type,
    s.option_name,
    s.is_growth,
    s.isin_growth,
    b.status = 'success'               as has_history,
    b.first_date                       as history_start,
    s.dbt_valid_from                   as valid_from,
    s.dbt_valid_to                     as valid_to,
    s.dbt_valid_to is null             as is_current
from {{ ref('snap_scheme') }} s
left join {{ source('raw', 'backfill_status') }} b using (scheme_code)
