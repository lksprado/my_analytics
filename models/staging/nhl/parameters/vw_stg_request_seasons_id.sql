{{ 
  config(
    materialized = 'materialized_view',
    tags = ['nhl','staging', 'parameters']
  )
}}

WITH source AS (

    SELECT payload::INT AS season_id
    FROM {{ source('nhl', 'nhl_raw_all_seasons_id') }}

),

max_season AS (

    SELECT MAX(season_id) AS max_season_id
    FROM source

),

final AS (

    SELECT DISTINCT
        s.season_id,
        s.season_id = m.max_season_id AS is_current,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM source AS s
    CROSS JOIN max_season AS m
    ORDER BY s.season_id DESC

)

SELECT * FROM final
