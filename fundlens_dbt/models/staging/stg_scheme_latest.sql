-- latest known details for each scheme (input for the SCD2 snapshot)
select distinct on (scheme_code)
    scheme_code, scheme_name, fund_house, scheme_category, asset_class,
    sub_category, plan_type, option_name, is_growth, isin_growth
from {{ ref('stg_amfi_nav_daily') }}
order by scheme_code, nav_date desc
