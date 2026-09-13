{{ 
  config(
    materialized = 'table',
    tags = ['nhl','staging', 'player_id'],
    post_hook = [
        "create index if not exists idx_club_goalies on {{ this }} (season_id, player_id)"
    ]
  )
}}

WITH base AS (
    SELECT * FROM {{ ref('stg_base_all_club_stats') }}
),

goalies AS (
    SELECT
        base.season_id,
        base.game_type_id,
        'goalie'                             AS player_type,
        (p ->> 'playerId')::INT              AS player_id,
        (p ->> 'wins')::INT                  AS wins,
        (p ->> 'goals')::INT                 AS goals,
        (p ->> 'saves')::INT                 AS saves,
        (p ->> 'losses')::INT                AS losses,
        (p ->> 'points')::INT                AS points,
        (p ->> 'assists')::INT               AS assists,
        (p ->> 'shutouts')::INT              AS shutouts,
        (p ->> 'timeOnIce')::INT             AS toi,
        (p ->> 'gamesPlayed')::INT           AS games_played,
        (p ->> 'gamesStarted')::INT          AS games_started,
        (p ->> 'goalsAgainst')::INT          AS goals_against,
        (p ->> 'shotsAgainst')::INT          AS shots_against,
        (p ->> 'penaltyMinutes')::INT        AS pim,
        (p ->> 'savePercentage')::FLOAT      AS save_pctg,
        (p ->> 'goalsAgainstAverage')::FLOAT AS goals_against_average,
        (p -> 'firstName' ->> 'default')     AS player_first_name,
        (p -> 'lastName' ->> 'default')      AS player_last_name,
        (p ->> 'headshot')                   AS player_picture
    FROM base,
        JSONB_ARRAY_ELEMENTS(payload -> 'goalies') AS p
)

SELECT * FROM goalies
