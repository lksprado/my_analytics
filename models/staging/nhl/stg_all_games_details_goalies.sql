{{ 
  config(
    materialized = 'incremental',
    on_schema_change = 'append_new_columns',
    unique_key = ['game_id', 'player_id'],
    tags = ['nhl', 'staging', 'player_id'],
    post_hook = [
        "create index if not exists idx_games_details_goalies on {{ this }} (game_id, player_id)"
    ]
  )
}}

WITH base AS (
    SELECT *
    FROM {{ ref('stg_base_all_games_details') }}
    {% if is_incremental() %}
        where game_id not in (
            select distinct game_id
            from {{ this }}
        )
    {% endif %}
),

away_goalies AS (
    SELECT
        game_id,
        'away'                                                      AS team_side,
        'goalie'                                                    AS player_type,
        (p ->> 'playerId')::INT                                     AS player_id,
        (p -> 'name' ->> 'default')                                 AS player_name,
        (p ->> 'position')                                          AS position,
        (p ->> 'sweaterNumber')::INT                                AS sweater_number,
        (p ->> 'toi')                                               AS time_on_ice,
        (p ->> 'starter')::BOOLEAN                                  AS is_starter,
        (p ->> 'goalsAgainst')::INT                                 AS goals_against,
        (p ->> 'shotsAgainst')::INT                                 AS shots_against,
        SPLIT_PART((p ->> 'saveShotsAgainst'), '/', 1)::INT         AS saves,
        (p ->> 'powerPlayGoalsAgainst')::INT                        AS powerplay_goals_against,
        SPLIT_PART((p ->> 'powerPlayShotsAgainst'), '/', 1)::INT    AS powerplay_saves,
        SPLIT_PART((p ->> 'powerPlayShotsAgainst'), '/', 2)::INT    AS powerplay_shots_against,
        (p ->> 'shorthandedGoalsAgainst')::INT                      AS shorthanded_goals_against,
        (p ->> 'evenStrengthGoalsAgainst')::INT                     AS evenstrenght_goals_against,
        SPLIT_PART((p ->> 'evenStrengthShotsAgainst'), '/', 1)::INT AS evenstrenght_saves,
        SPLIT_PART((p ->> 'evenStrengthShotsAgainst'), '/', 2)::INT AS evenstrenght_shots_against,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM base,
        JSONB_ARRAY_ELEMENTS(payload -> 'playerByGameStats' -> 'awayTeam' -> 'goalies') AS p
),

home_goalies AS (
    SELECT
        game_id,
        'home'                                                      AS team_side,
        'goalie'                                                    AS player_type,
        (p ->> 'playerId')::INT                                     AS player_id,
        (p -> 'name' ->> 'default')                                 AS player_name,
        (p ->> 'position')                                          AS position,
        (p ->> 'sweaterNumber')::INT                                AS sweater_number,
        (p ->> 'toi')                                               AS time_on_ice,
        (p ->> 'starter')::BOOLEAN                                  AS is_starter,
        (p ->> 'goalsAgainst')::INT                                 AS goals_against,
        (p ->> 'shotsAgainst')::INT                                 AS shots_against,
        SPLIT_PART((p ->> 'saveShotsAgainst'), '/', 1)::INT         AS saves,
        (p ->> 'powerPlayGoalsAgainst')::INT                        AS powerplay_goals_against,
        SPLIT_PART((p ->> 'powerPlayShotsAgainst'), '/', 1)::INT    AS powerplay_saves,
        SPLIT_PART((p ->> 'powerPlayShotsAgainst'), '/', 2)::INT    AS powerplay_shots_against,
        (p ->> 'shorthandedGoalsAgainst')::INT                      AS shorthanded_goals_against,
        (p ->> 'evenStrengthGoalsAgainst')::INT                     AS evenstrenght_goals_against,
        SPLIT_PART((p ->> 'evenStrengthShotsAgainst'), '/', 1)::INT AS evenstrenght_saves,
        SPLIT_PART((p ->> 'evenStrengthShotsAgainst'), '/', 2)::INT AS evenstrenght_shots_against,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM base,
        JSONB_ARRAY_ELEMENTS(payload -> 'playerByGameStats' -> 'homeTeam' -> 'goalies') AS p
)

SELECT * FROM away_goalies
UNION ALL
SELECT * FROM home_goalies
