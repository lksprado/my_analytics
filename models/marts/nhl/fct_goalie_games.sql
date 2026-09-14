{{
  config(
    tags = ['nhl'],
    )
}}

WITH
player_games AS (
    SELECT * FROM {{ ref('int_player_games_played') }}
    WHERE player_type = 'goalie'
),

goalie_stats AS (
    SELECT * FROM {{ ref('stg_all_games_details_goalies') }}
),

final AS (
    SELECT
        t3.game_sk,
        TO_CHAR(t1.game_date, 'YYYYMMDD')::INT AS game_date_sk,
        COALESCE(t4.player_sk, '-1')           AS player_sk,
        t5.team_sk,
        t6.team_sk                             AS opponent_team_sk,
        t1.is_home,
        t1.sweater_number,
        t2.is_starter,
        t1.toi_seconds,
        t2.shots_against,
        t2.saves,
        t2.goals_against,
        t2.powerplay_shots_against,
        t2.powerplay_saves,
        t2.powerplay_goals_against,
        t2.shorthanded_goals_against,
        t2.evenstrenght_shots_against          AS evenstrength_shots_against,
        t2.evenstrenght_saves                  AS evenstrength_saves,
        t2.evenstrenght_goals_against          AS evenstrength_goals_against
    FROM player_games AS t1
    INNER JOIN goalie_stats AS t2
        ON t1.game_id = t2.game_id
        AND t1.player_id = t2.player_id
    INNER JOIN {{ ref('dim_game') }} AS t3
        ON t1.game_id = t3.game_id
    LEFT JOIN {{ ref('dim_player') }} AS t4
        ON t1.player_id = t4.player_id
    INNER JOIN {{ ref('dim_team') }} AS t5
        ON t1.team_id = t5.team_id
    INNER JOIN {{ ref('dim_team') }} AS t6
        ON t1.opponent_team_id = t6.team_id
)

SELECT * FROM final
