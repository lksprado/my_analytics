{{
  config(
    tags = ['nhl'],
    )
}}

WITH
team_game_periods AS (
    SELECT * FROM {{ ref('int_team_game_periods') }}
),

final AS (
    SELECT
        t2.game_sk,
        TO_CHAR(t1.game_date, 'YYYYMMDD')::INT AS game_date_sk,
        t3.team_sk,
        t4.team_sk                             AS opponent_team_sk,
        t1.is_home,
        t1.period_number,
        t1.period_type,
        t1.goals_for,
        t1.goals_against,
        t1.shots_for,
        t1.shots_against
    FROM team_game_periods AS t1
    INNER JOIN {{ ref('dim_game') }} AS t2
        ON t1.game_id = t2.game_id
    INNER JOIN {{ ref('dim_team') }} AS t3
        ON t1.team_id = t3.team_id
    INNER JOIN {{ ref('dim_team') }} AS t4
        ON t1.opponent_team_id = t4.team_id
)

SELECT * FROM final
