{{
  config(
    tags = ['nhl'],
    )
}}

WITH
player_games AS (
    SELECT * FROM {{ ref('int_player_games_played') }}
    WHERE player_type <> 'goalie'
),

skater_stats AS (
    SELECT * FROM {{ ref('stg_all_games_details_skaters') }}
),

final AS (
    SELECT
        t3.game_sk,
        TO_CHAR(t1.game_date, 'YYYYMMDD')::INT AS game_date_sk,
        COALESCE(t4.player_sk, '-1')           AS player_sk,
        t5.team_sk,
        t6.team_sk                             AS opponent_team_sk,
        t1.is_home,
        t1.player_type,
        t1.position,
        t1.sweater_number,
        t2.goals,
        t2.assists,
        t2.points,
        t2.shots_on_goal,
        t2.hits,
        t2.blocked_shots,
        t2.plus_minus,
        t1.toi_seconds
    FROM player_games AS t1
    INNER JOIN skater_stats AS t2
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
