{{
  config(
    tags = ['nhl'],
    )
}}

WITH
team_games AS (
    SELECT * FROM {{ ref('int_team_games') }}
),

-- DISTINCT porque um jogo pode ter várias brigas e duplicaria o grão
fights_per_game AS (
    SELECT DISTINCT game_id
    FROM {{ ref('dim_fight') }}
    WHERE game_id IS NOT NULL
),

final AS (
    SELECT
        t2.game_sk,
        TO_CHAR(t1.game_date, 'YYYYMMDD')::INT AS game_date_sk,
        t3.team_sk,
        t4.team_sk                             AS opponent_team_sk,
        t1.is_home,
        t1.goals_for,
        t1.goals_against,
        t1.shots_for,
        t1.shots_against,
        t1.hits,
        t1.penalty_minutes,
        t1.blocked_shots,
        t1.giveaways,
        t1.takeaways,
        t1.faceoff_win_pctg,
        t1.powerplay_pctg,
        t1.is_win,
        t1.is_regulation_loss,
        t1.is_ot_loss,
        t1.is_tie,
        t1.standing_points,
        t5.game_id IS NOT NULL                 AS has_fight
    FROM team_games AS t1
    INNER JOIN {{ ref('dim_game') }} AS t2
        ON t1.game_id = t2.game_id
    -- INNER descarta as finais da Stanley Cup 1918-1926 contra times da PCHA/WCHL, ausentes da dim_team
    INNER JOIN {{ ref('dim_team') }} AS t3
        ON t1.team_id = t3.team_id
    INNER JOIN {{ ref('dim_team') }} AS t4
        ON t1.opponent_team_id = t4.team_id
    LEFT JOIN fights_per_game AS t5
        ON t1.game_id = t5.game_id
)

SELECT * FROM final
