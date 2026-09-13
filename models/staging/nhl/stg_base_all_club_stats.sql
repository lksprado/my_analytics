{{ 
  config(
    materialized = 'ephemeral',
    tags = ['nhl', 'staging']
  )
}}

SELECT
    payload,
    (payload ->> 'season')::INT   AS season_id,
    (payload ->> 'gameType')::INT AS game_type_id
FROM {{ source('nhl', 'nhl_raw_all_club_stats') }}
