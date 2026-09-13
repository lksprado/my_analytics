{{ 
  config(
    materialized = 'materialized_view',
    tags = ['nhl','staging', 'player_id', 'parameters']
  )
}}

WITH
base AS (
    SELECT
        season_id,
        MAX(game_type_id) AS game_type_id
    FROM {{ ref('stg_all_games_summary') }}
    WHERE season_id = (SELECT MAX(season_id) FROM {{ ref('stg_all_games_summary') }})
    GROUP BY season_id
),

players AS (
    SELECT * FROM {{ ref('vw_stg_request_players_id') }}
),

final AS (
    SELECT * FROM base,
        players
)

SELECT * FROM final
