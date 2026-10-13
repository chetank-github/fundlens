-- warn if large daily moves remain after spike cleaning
{{ config(severity='warn') }}
select * from {{ ref('dq_nav_issues') }} where issue = 'big_move_kept'