{{ 
  config(
    materialized = 'incremental',
    unique_key = ['player_id', 'game_id', 'game_type_id'],
    tags = ['nhl','staging', 'player_id'],
    post_hook = [
        "create index if not exists idx_games_log on {{ this }} (game_id, player_id)",
        "create index if not exists idx_player_log_date on {{ this }} (player_id, game_date)"
    ]
  )
}}

WITH source AS (

    SELECT *
    FROM {{ source('nhl', 'nhl_raw_all_player_game_log') }}
),

stats_games AS (
    SELECT
        SPLIT_PART(source_filename, '_', 1)::INT AS player_id,
        (payload ->> 'seasonId')::INT            AS season_id,
        (payload ->> 'gameTypeId')::INT          AS game_type_id,
        (p ->> 'pim')::INT                       AS pim,
        (p ->> 'goals')::INT                     AS goals,
        (p ->> 'shots')::INT                     AS shots,
        (p ->> 'gameId')::INT                    AS game_id,
        (p ->> 'points')::INT                    AS points,
        (p ->> 'shifts')::INT                    AS shifts,
        (p ->> 'assists')::INT                   AS assists,
        (p ->> 'otGoals')::INT                   AS overtime_goals,
        (p ->> 'gameDate')::DATE                 AS game_date,
        (p ->> 'plusMinus')::INT                 AS plus_minus,
        (p ->> 'powerPlayGoals')::INT            AS powerplay_goals,
        (p ->> 'powerPlayPoints')::INT           AS powerplay_points,
        (p ->> 'gameWinningGoals')::INT          AS game_winning_goals,
        (p ->> 'shorthandedGoals')::INT          AS shorthanded_goals,
        (p ->> 'shorthandedPoints')::INT         AS shorthanded_points,
        (p ->> 'savePctg')::FLOAT                AS save_pctg,
        (p ->> 'shutouts')::INT                  AS is_shutout,
        (p ->> 'gamesStarted')::INT              AS is_starter,
        (p ->> 'goalsAgainst')::INT              AS goals_against,
        (p ->> 'shotsAgainst')::INT              AS shots_against,
        (p ->> 'toi')                            AS toi,
        (p ->> 'teamAbbrev')                     AS team_abbrev,
        (p ->> 'homeRoadFlag')                   AS home_road_flag,
        (p ->> 'opponentAbbrev')                 AS opponent_abbrev,
        (p ->> 'decision')                       AS game_decision
    FROM source,
        JSONB_ARRAY_ELEMENTS(payload -> 'gameLog') AS p
)

SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY player_id, season_id ORDER BY game_id)::INT
        AS game_played_number
FROM stats_games
{% if is_incremental() %}
    where game_date >= (select max(game_date) from {{ this }})
{% endif %}
