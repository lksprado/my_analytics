{{ 
  config(
    materialized = 'incremental',
    unique_key = ['game_id', 'player_id'],
    tags = ['nhl', 'staging', 'player_id'],
    post_hook = [
        "create index if not exists idx_games_details_skaters on {{ this }} (game_id, player_id)"
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

away_defense AS (
    SELECT
        game_id,
        'away'                       AS team_side,
        'defense'                    AS player_type,
        (p ->> 'playerId')::INT      AS player_id,
        (p -> 'name' ->> 'default')  AS player_name,
        (p ->> 'position')           AS position,
        (p ->> 'sweaterNumber')::INT AS sweater_number,
        (p ->> 'toi')                AS time_on_ice,
        (p ->> 'goals')::INT         AS goals,
        (p ->> 'assists')::INT       AS assists,
        (p ->> 'points')::INT        AS points,
        (p ->> 'sog')::INT           AS shots_on_goal,
        (p ->> 'hits')::INT          AS hits,
        (p ->> 'blockedShots')::INT  AS blocked_shots,
        (p ->> 'plusMinus')::INT     AS plus_minus
    FROM base,
        JSONB_ARRAY_ELEMENTS(payload -> 'playerByGameStats' -> 'awayTeam' -> 'defense') AS p
),

away_forwards AS (
    SELECT
        game_id,
        'away'                       AS team_side,
        'forward'                    AS player_type,
        (p ->> 'playerId')::INT      AS player_id,
        (p -> 'name' ->> 'default')  AS player_name,
        (p ->> 'position')           AS position,
        (p ->> 'sweaterNumber')::INT AS sweater_number,
        (p ->> 'toi')                AS time_on_ice,
        (p ->> 'goals')::INT         AS goals,
        (p ->> 'assists')::INT       AS assists,
        (p ->> 'points')::INT        AS points,
        (p ->> 'sog')::INT           AS shots_on_goal,
        (p ->> 'hits')::INT          AS hits,
        (p ->> 'blockedShots')::INT  AS blocked_shots,
        (p ->> 'plusMinus')::INT     AS plus_minus
    FROM base,
        JSONB_ARRAY_ELEMENTS(payload -> 'playerByGameStats' -> 'awayTeam' -> 'forwards') AS p
),

home_defense AS (
    SELECT
        game_id,
        'home'                       AS team_side,
        'defense'                    AS player_type,
        (p ->> 'playerId')::INT      AS player_id,
        (p -> 'name' ->> 'default')  AS player_name,
        (p ->> 'position')           AS position,
        (p ->> 'sweaterNumber')::INT AS sweater_number,
        (p ->> 'toi')                AS time_on_ice,
        (p ->> 'goals')::INT         AS goals,
        (p ->> 'assists')::INT       AS assists,
        (p ->> 'points')::INT        AS points,
        (p ->> 'sog')::INT           AS shots_on_goal,
        (p ->> 'hits')::INT          AS hits,
        (p ->> 'blockedShots')::INT  AS blocked_shots,
        (p ->> 'plusMinus')::INT     AS plus_minus
    FROM base,
        JSONB_ARRAY_ELEMENTS(payload -> 'playerByGameStats' -> 'homeTeam' -> 'defense') AS p
),

home_forwards AS (
    SELECT
        game_id,
        'home'                       AS team_side,
        'forward'                    AS player_type,
        (p ->> 'playerId')::INT      AS player_id,
        (p -> 'name' ->> 'default')  AS player_name,
        (p ->> 'position')           AS position,
        (p ->> 'sweaterNumber')::INT AS sweater_number,
        (p ->> 'toi')                AS time_on_ice,
        (p ->> 'goals')::INT         AS goals,
        (p ->> 'assists')::INT       AS assists,
        (p ->> 'points')::INT        AS points,
        (p ->> 'sog')::INT           AS shots_on_goal,
        (p ->> 'hits')::INT          AS hits,
        (p ->> 'blockedShots')::INT  AS blocked_shots,
        (p ->> 'plusMinus')::INT     AS plus_minus
    FROM base,
        JSONB_ARRAY_ELEMENTS(payload -> 'playerByGameStats' -> 'homeTeam' -> 'forwards') AS p
),

all_skaters AS (
    SELECT * FROM away_defense
    UNION ALL
    SELECT * FROM away_forwards
    UNION ALL
    SELECT * FROM home_defense
    UNION ALL
    SELECT * FROM home_forwards
)

SELECT * FROM all_skaters
