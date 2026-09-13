{{
  config(
    materialized = 'materialized_view',
    tags = ['nhl','staging', 'game_id', 'parameters']
  )
}}

WITH
current_season AS (
    SELECT season_id
    FROM {{ ref('vw_stg_request_seasons_id') }}
    WHERE is_current = TRUE
),

games_happened AS (
    SELECT DISTINCT game_id
    FROM {{ ref('stg_all_games_summary') }}
    WHERE
        has_happened_by_status = TRUE
        AND season_id = (SELECT season_id FROM current_season)
),

games_details AS (
    SELECT DISTINCT
        game_id,
        TRUE AS has_games_details
    FROM {{ ref('stg_all_games_details') }}
),

games_summary_details AS (
    SELECT DISTINCT
        game_id,
        TRUE AS has_games_summary_details
    FROM {{ ref('stg_all_games_summary_details') }}
),

play_by_play AS (
    SELECT
        game_id,
        TRUE AS has_play_by_play
    FROM {{ ref('stg_all_play_by_play') }}
    GROUP BY game_id
),

final AS (
    SELECT
        gh.game_id,

        COALESCE(gd.has_games_details, FALSE)          AS has_games_details,
        COALESCE(gsd.has_games_summary_details, FALSE) AS has_games_summary_details,
        COALESCE(pbp.has_play_by_play, FALSE)          AS has_play_by_play,

        COALESCE(
            COALESCE(gd.has_games_details, FALSE)
            AND COALESCE(gsd.has_games_summary_details, FALSE)
            AND COALESCE(pbp.has_play_by_play, FALSE), FALSE
        )                                              AS is_fully_synced

    FROM games_happened AS gh
    LEFT JOIN games_details AS gd
        ON gh.game_id = gd.game_id
    LEFT JOIN games_summary_details AS gsd
        ON gh.game_id = gsd.game_id
    LEFT JOIN play_by_play AS pbp
        ON gh.game_id = pbp.game_id
)

SELECT *
FROM final
WHERE is_fully_synced IS FALSE
