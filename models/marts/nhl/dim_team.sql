{{
  config(
    tags = ['nhl'],
    )
}}

with 

game_details as (
    select
        home_team_id as id,
        string_agg(distinct home_team_logo, ', ' order by home_team_logo) as logo,
        string_agg(distinct home_team_darklogo, ', ' order by home_team_darklogo) as darklogo,
        string_agg(distinct home_team_placename, ', ' order by home_team_placename)
            as place_name,
        string_agg(distinct home_team_commonname, ', ' order by home_team_commonname)
            as common_name,
        max(season_id) as latest_season_id,
        min(season_id) as first_season_id
    from {{ ref('stg_all_games_details') }}
    group by home_team_id
),

teams as (
    select
        {{ dbt_utils.generate_surrogate_key(['t1.id', 't1.abbrev_name']) }} as team_sk,
        t1.id,
        t1.abbrev_name,
        t1.full_name,
        t2.place_name,
        t2.common_name,
        t2.first_season_id,
        t2.latest_season_id,
        t3.is_current as is_active
    from {{ ref('stg_all_teams') }} as t1
    left join game_details as t2
        on t1.id = t2.id
    left join {{ ref('vw_stg_request_seasons_id') }} as t3
        on t2.latest_season_id = t3.season_id
    left join {{ ref('vw_stg_request_seasons_id') }} as t4
        on t2.first_season_id = t4.season_id
    where t1.id < 99
)

select * from teams
