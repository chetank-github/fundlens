-- warn if any active fund has unrealistic numbers (usually bad source data)
{{ config(severity='warn') }}
select scheme_code, scheme_name, return_1y, cagr_3y, volatility_3y
from {{ ref('mart_fund_metrics') }}
where is_active
  and (abs(return_1y) > 2 or abs(cagr_3y) > 1 or volatility_3y > 1)