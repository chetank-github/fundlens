select
    scheme_code,
    nav_date,
    nav,
    trim(scheme_name)                                   as scheme_name,
    trim(fund_house)                                    as fund_house,
    trim(scheme_category)                               as scheme_category,
    trim(replace(split_part(scheme_category, ' - ', 1), ' Scheme', '')) as asset_class,
    nullif(trim(split_part(scheme_category, ' - ', 2)), '')             as sub_category,
    case when plan ilike 'direct%' then 'Direct'
         when plan ilike 'regular%' then 'Regular' end  as plan_type,
    trim(option)                                        as option_name,
    option ilike '%growth%'                             as is_growth,
    isin_growth,
    loaded_at
from {{ source('raw', 'amfi_nav_daily') }}
