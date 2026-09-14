{{
  config(
    tags = ['nhl'],
    )
}}

WITH
games AS (
    SELECT
        game_id,
        game_date,
        home_team_id,
        away_team_id
    FROM {{ ref('int_games_detailed') }}
),

boxscore AS (
    SELECT game_id, player_id, player_type, position, sweater_number, team_side, time_on_ice
    FROM {{ ref('stg_all_games_details_skaters') }}
    UNION ALL
    SELECT game_id, player_id, player_type, position, sweater_number, team_side, time_on_ice
    FROM {{ ref('stg_all_games_details_goalies') }}
),

final AS (
    SELECT
        t1.game_id,
        t2.game_date,
        t1.player_id,
        t1.player_type,
        t1.position,
        t1.sweater_number,
        t1.team_side = 'home'                                                                  AS is_home,
        CASE t1.team_side WHEN 'home' THEN t2.home_team_id ELSE t2.away_team_id END            AS team_id,
        CASE t1.team_side WHEN 'home' THEN t2.away_team_id ELSE t2.home_team_id END            AS opponent_team_id,
        SPLIT_PART(t1.time_on_ice, ':', 1)::INT * 60 + SPLIT_PART(t1.time_on_ice, ':', 2)::INT AS toi_seconds
    FROM boxscore AS t1
    INNER JOIN games AS t2
        ON t1.game_id = t2.game_id
)

SELECT * FROM final
