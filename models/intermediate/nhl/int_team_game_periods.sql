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

periods AS (
    SELECT * FROM {{ ref('stg_all_games_summary_periods') }}
),

final AS (
    SELECT
        t1.game_id,
        t2.game_date,
        t1.period_number,
        LOWER(t1.period_type) AS period_type,
        side.team_id,
        side.opponent_team_id,
        side.is_home,
        side.goals_for,
        side.goals_against,
        side.shots_for,
        side.shots_against,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM periods AS t1
    INNER JOIN games AS t2
        ON t1.game_id = t2.game_id
    CROSS JOIN LATERAL (
        VALUES
            (t2.home_team_id, t2.away_team_id, TRUE,  t1.home_goals, t1.away_goals, t1.home_shots, t1.away_shots),
            (t2.away_team_id, t2.home_team_id, FALSE, t1.away_goals, t1.home_goals, t1.away_shots, t1.home_shots)
    ) AS side (team_id, opponent_team_id, is_home, goals_for, goals_against, shots_for, shots_against)
)

SELECT * FROM final
