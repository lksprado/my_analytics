{{
  config(
    materialized = 'ephemeral',
    tags = ['nhl', 'staging', 'game_id']
  )
}}

WITH source AS (
    SELECT
        payload,
        source_filename,
        SPLIT_PART(source_filename, '_', 2)::INT AS game_id
    FROM {{ source('nhl', 'nhl_raw_all_games_summary_details') }}
    WHERE SPLIT_PART(source_filename, '_', 2) IS NOT NULL
)

SELECT * FROM source
