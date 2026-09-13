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

goalies_club_stats AS (
    SELECT DISTINCT player_id
    FROM {{ ref('stg_all_club_stats_goalies') }} AS t1
    INNER JOIN base AS t2
        ON
        t1.season_id = t2.season_id
        AND t1.game_type_id = t2.game_type_id
),

skaters_club_stats AS (
    SELECT DISTINCT player_id
    FROM {{ ref('stg_all_club_stats_skaters') }} AS t1
    INNER JOIN base AS t2
        ON
        t1.season_id = t2.season_id
        AND t1.game_type_id = t2.game_type_id
),

final AS (
    SELECT * FROM goalies_club_stats
    UNION
    SELECT * FROM skaters_club_stats
)

SELECT *
FROM final
