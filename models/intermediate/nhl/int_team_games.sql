{{
  config(
    tags = ['nhl'],
    )
}}

WITH
games AS (
    SELECT * FROM {{ ref('int_games_detailed') }}
    WHERE has_happened_by_status
),

team_stats AS (
    SELECT * FROM {{ ref('stg_all_games_summary_details') }}
),

team_games AS (
    SELECT
        t1.game_id,
        t1.season_id,
        t1.game_type_id,
        t1.game_date,
        t1.game_outcome_last_period,
        side.team_id,
        side.opponent_team_id,
        side.is_home,
        side.goals_for,
        side.goals_against,
        side.shots_for,
        side.shots_against,
        side.hits,
        side.penalty_minutes,
        side.blocked_shots,
        side.giveaways,
        side.takeaways,
        side.faceoff_win_pctg,
        side.powerplay_pctg
    FROM games AS t1
    LEFT JOIN team_stats AS t2
        ON t1.game_id = t2.game_id
    CROSS JOIN LATERAL (
        VALUES
            (
                t1.home_team_id, t1.away_team_id, TRUE, t1.home_score, t1.away_score, t2.home_sog, t2.away_sog,
                t2.home_hits, t2.home_pim, t2.home_blocked_shots, t2.home_giveaways, t2.home_takeaways,
                t2.home_faceoff_winning_pctg, t2.home_powerplay_pctg
            ),
            (
                t1.away_team_id, t1.home_team_id, FALSE, t1.away_score, t1.home_score, t2.away_sog, t2.home_sog,
                t2.away_hits, t2.away_pim, t2.away_blocked_shots, t2.away_giveaways, t2.away_takeaways,
                t2.away_faceoff_winning_pctg, t2.away_powerplay_pctg
            )
    ) AS side (
        team_id, opponent_team_id, is_home, goals_for, goals_against, shots_for, shots_against,
        hits, penalty_minutes, blocked_shots, giveaways, takeaways,
        faceoff_win_pctg, powerplay_pctg
    )
),

results AS (
    SELECT
        *,
        goals_for > goals_against                                                          AS is_win,
        goals_for = goals_against                                                          AS is_tie,
        goals_for < goals_against AND game_outcome_last_period IN ('ot', 'so')             AS is_ot_loss,
        goals_for < goals_against AND game_outcome_last_period NOT IN ('ot', 'so')         AS is_regulation_loss
    FROM team_games
),

final AS (
    SELECT
        game_id,
        game_date,
        team_id,
        opponent_team_id,
        is_home,
        goals_for,
        goals_against,
        shots_for,
        shots_against,
        hits,
        penalty_minutes,
        blocked_shots,
        giveaways,
        takeaways,
        faceoff_win_pctg,
        powerplay_pctg,
        is_win,
        is_regulation_loss,
        is_ot_loss,
        is_tie,
        -- o ponto por derrota na prorrogação só existe desde 1999-00
        CASE
            WHEN game_type_id <> 2 THEN NULL
            WHEN is_win THEN 2
            WHEN is_tie THEN 1
            WHEN is_ot_loss AND season_id >= 19992000 THEN 1
            ELSE 0
        END AS standing_points,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM results
)

SELECT * FROM final
