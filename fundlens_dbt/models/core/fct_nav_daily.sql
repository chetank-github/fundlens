{{ config(
    materialized='incremental',
    unique_key=['scheme_code', 'nav_date'],
    incremental_strategy='delete+insert',
    indexes=[{'columns': ['scheme_code', 'nav_date'], 'unique': True}]
) }}

-- one row per scheme per day, only for schemes we track (history downloaded)
with tracked as (
    select scheme_code
    from {{ source('raw', 'backfill_status') }}
    where status = 'success'
),

all_navs as (
    select scheme_code, nav_date, nav, 'amfi' as source, 1 as priority, loaded_at
    from {{ ref('stg_amfi_nav_daily') }}
    where scheme_code in (select scheme_code from tracked)
    union all
    select scheme_code, nav_date, nav, 'mfapi' as source, 2 as priority, loaded_at
    from {{ ref('stg_nav_history') }}
    where scheme_code in (select scheme_code from tracked)
)

{% if is_incremental() %}
-- only rebuild the scheme-days that got new or updated rows since the last run
, changed as (
    select distinct scheme_code, nav_date
    from all_navs
    where loaded_at > (select max(loaded_at) from {{ this }})
)
{% endif %}

select distinct on (a.scheme_code, a.nav_date)
    a.scheme_code,
    a.nav_date,
    a.nav,
    a.source,
    a.loaded_at
from all_navs a
{% if is_incremental() %}
join changed c using (scheme_code, nav_date)
{% endif %}
order by a.scheme_code, a.nav_date, a.priority
