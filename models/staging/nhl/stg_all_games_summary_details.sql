{{
  config(
    materialized = 'incremental',
    on_schema_change = 'append_new_columns',
    unique_key = ['game_id'],
    tags = ['nhl', 'staging', 'game_id'],
    post_hook = [
        "create index if not exists idx_games_summary_details on {{ this }} (game_id)"
    ]
  )
}}

WITH base AS (
    SELECT *
    FROM {{ ref('stg_base_all_games_summary_details') }}
    {% if is_incremental() %}
        where game_id >= (select max(game_id) from {{ this }})
    {% endif %}
),

exploded AS (
    SELECT
        game_id,
        p ->> 'category'    AS metric,
        (p ->> 'awayValue') AS away_value,
        (p ->> 'homeValue') AS home_value
    FROM base,
        JSONB_ARRAY_ELEMENTS(payload -> 'teamGameStats') AS p
),

wide AS (
    SELECT
        game_id,
        MAX(away_value) FILTER (WHERE metric = 'sog')::INT                  AS away_sog,
        MAX(home_value) FILTER (WHERE metric = 'sog')::INT                  AS home_sog,
        MAX(away_value) FILTER (WHERE metric = 'faceoffWinningPctg')::FLOAT
            AS away_faceoff_winning_pctg,
        MAX(home_value) FILTER (WHERE metric = 'faceoffWinningPctg')::FLOAT
            AS home_faceoff_winning_pctg,
        MAX(away_value) FILTER (WHERE metric = 'powerPlayPctg')::FLOAT      AS away_powerplay_pctg,
        MAX(home_value) FILTER (WHERE metric = 'powerPlayPctg')::FLOAT      AS home_powerplay_pctg,
        MAX(away_value) FILTER (WHERE metric = 'pim')::INT                  AS away_pim,
        MAX(home_value) FILTER (WHERE metric = 'pim')::INT                  AS home_pim,
        MAX(away_value) FILTER (WHERE metric = 'hits')::INT                 AS away_hits,
        MAX(home_value) FILTER (WHERE metric = 'hits')::INT                 AS home_hits,
        MAX(away_value) FILTER (WHERE metric = 'blockedShots')::INT         AS away_blocked_shots,
        MAX(home_value) FILTER (WHERE metric = 'blockedShots')::INT         AS home_blocked_shots,
        MAX(away_value) FILTER (WHERE metric = 'giveaways')::INT            AS away_giveaways,
        MAX(home_value) FILTER (WHERE metric = 'giveaways')::INT            AS home_giveaways,
        MAX(away_value) FILTER (WHERE metric = 'takeaways')::INT            AS away_takeaways,
        MAX(home_value) FILTER (WHERE metric = 'takeaways')::INT            AS home_takeaways,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM exploded
    GROUP BY game_id
)

SELECT * FROM wide
ORDER BY game_id DESC
