-- pairs the Direct and Regular plan of the same fund and compares returns.
-- the gap is roughly the extra yearly cost (commission) of the Regular plan.
with named as (
    select
        *,
        trim(regexp_replace(
            regexp_replace(lower(scheme_name), '\m(direct|regular|plan|growth|option)\M', '', 'g'),
            '[^a-z0-9]+', ' ', 'g'
        )) as base_name
    from {{ ref('mart_fund_metrics') }}
    where is_active
),

direct as (
    select distinct on (fund_house, sub_category, base_name) *
    from named where plan_type = 'Direct'
    order by fund_house, sub_category, base_name, scheme_code
),

regular as (
    select distinct on (fund_house, sub_category, base_name) *
    from named where plan_type = 'Regular'
    order by fund_house, sub_category, base_name, scheme_code
)

select
    d.fund_house,
    d.sub_category,
    d.base_name                              as fund_name,
    d.scheme_code                            as direct_code,
    r.scheme_code                            as regular_code,
    d.return_1y                              as direct_return_1y,
    r.return_1y                              as regular_return_1y,
    d.cagr_3y                                as direct_cagr_3y,
    r.cagr_3y                                as regular_cagr_3y,
    d.cagr_5y                                as direct_cagr_5y,
    r.cagr_5y                                as regular_cagr_5y,
    d.return_1y - r.return_1y                as gap_1y,
    d.cagr_3y   - r.cagr_3y                  as gap_3y,
    d.cagr_5y   - r.cagr_5y                  as gap_5y
from direct d
join regular r using (fund_house, sub_category, base_name)
