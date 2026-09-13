{{ 
  config(
    materialized = 'table',
    tags = ['nhl','staging', 'player_id'],
    post_hook = [
        "create index if not exists idx_club_skaters on {{ this }} (season_id, player_id)"
    ]
  )
}}

WITH base AS (
    SELECT * FROM {{ ref('stg_base_all_club_stats') }}
),

skaters AS (
    SELECT
        season_id,
        game_type_id,
        'skater'                             AS player_type,
        (p ->> 'playerId')::INT              AS player_id,
        (p ->> 'goals')::INT                 AS goals,
        (p ->> 'shots')::INT                 AS shots,
        (p ->> 'points')::INT                AS points,
        (p ->> 'assists')::INT               AS assists,
        (p ->> 'plusMinus')::INT             AS plus_minus,
        (p ->> 'gamesPlayed')::INT           AS games_played,
        (p ->> 'shootingPctg')::FLOAT        AS shooting_pctg,
        (p ->> 'overtimeGoals')::INT         AS overtime_goals,
        (p ->> 'faceoffWinPctg')::FLOAT      AS faceoff_win_pctg,
        (p ->> 'penaltyMinutes')::INT        AS pim,
        (p ->> 'powerPlayGoals')::INT        AS powerplay_goals,
        (p ->> 'avgShiftsPerGame')::FLOAT    AS avg_shifts_per_game,
        (p ->> 'gameWinningGoals')::INT      AS game_winning_goals,
        (p ->> 'shorthandedGoals')::INT      AS shorthanded_goals,
        (p ->> 'avgTimeOnIcePerGame')::FLOAT AS avg_toi_per_game_seconds,
        (p -> 'firstName' ->> 'default')     AS player_first_name,
        (p -> 'lastName' ->> 'default')      AS player_last_name,
        (p ->> 'headshot')                   AS player_picture,
        (p ->> 'positionCode')               AS position
    FROM base,
        JSONB_ARRAY_ELEMENTS(payload -> 'skaters') AS p
)

SELECT * FROM skaters
