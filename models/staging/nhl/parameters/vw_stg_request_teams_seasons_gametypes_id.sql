{{ 
  config(
    materialized = 'materialized_view',
    tags = ['nhl','staging', 'parameters']
  )
}}

WITH
away AS (
    SELECT DISTINCT
        away_team_abbrev AS team_id,
        season_id,
        game_type_id
    FROM {{ ref('stg_all_games_details') }}
),

home AS (
    SELECT DISTINCT
        home_team_abbrev AS team_id,
        season_id,
        game_type_id
    FROM {{ ref('stg_all_games_details') }}
),

final AS (
    SELECT * FROM away
    UNION
    SELECT * FROM home
)

SELECT *
FROM final
WHERE season_id = (SELECT MAX(season_id) FROM final) AND game_type_id IN (2, 3)
ORDER BY 1 ASC, 2 DESC
