{{
  config(
    materialized = 'incremental',
    on_schema_change = 'append_new_columns',
    unique_key = ['game_id', 'period_number'],
    tags = ['nhl', 'staging'],
    post_hook = [
        "create index if not exists idx_games_summary_periods on {{ this }} (game_id, period_number)"
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

shots AS (
    SELECT
        game_id,
        (p -> 'periodDescriptor' ->> 'number')::INT AS period_number,
        (p ->> 'away')::INT                         AS away_shots,
        (p ->> 'home')::INT                         AS home_shots,
        (p -> 'periodDescriptor' ->> 'periodType')  AS period_type
    FROM base,
        JSONB_ARRAY_ELEMENTS(payload -> 'shotsByPeriod') AS p
),

goals AS (
    SELECT
        game_id,
        (p -> 'periodDescriptor' ->> 'number')::INT AS period_number,
        (p ->> 'away')::INT                         AS away_goals,
        (p ->> 'home')::INT                         AS home_goals,
        (p -> 'periodDescriptor' ->> 'periodType')  AS period_type
    FROM base,
        JSONB_ARRAY_ELEMENTS(payload -> 'linescore' -> 'byPeriod') AS p
),

joined AS (
    SELECT
        s.game_id,
        s.period_number,
        s.period_type,
        s.away_shots,
        s.home_shots,
        g.away_goals,
        g.home_goals,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM shots AS s
    INNER JOIN goals AS g
        ON
        s.game_id = g.game_id
        AND s.period_number = g.period_number
)

SELECT * FROM joined
ORDER BY game_id, period_number
