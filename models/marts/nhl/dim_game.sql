{{
  config(
    tags = ['nhl'],
    )
}}

WITH
games AS (
    SELECT * FROM {{ ref('int_games_detailed') }}
),

seasons AS (
    SELECT * FROM {{ ref('vw_stg_request_seasons_id') }}
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['t1.game_id']) }}                     AS game_sk,
        t1.game_id,
        t1.season_id,
        LEFT(t1.season_id::TEXT, 4) || '-' || RIGHT(t1.season_id::TEXT, 2)        AS season_label,
        COALESCE(t2.is_current, FALSE)                                              AS is_current_season,
        t1.game_type_id,
        t1.game_type_name,
        t1.game_number,
        t1.game_date,
        t1.game_start_timestamp_et,
        t1.game_date_timestamp_utc                                                  AS game_start_timestamp_utc,
        COALESCE(t1.game_state, 'unknown')                                          AS game_state,
        COALESCE(t1.game_schedule_state, 'unknown')                                 AS game_schedule_state,
        t1.regular_periods,
        t1.game_outcome_total_periods                                               AS total_periods,
        COALESCE(t1.game_outcome_last_period, 'unknown')                            AS outcome_last_period,
        COALESCE(t1.special_event_name, 'none')                                     AS special_event_name,
        t1.has_happened_by_status                                                   AS is_completed
    FROM games AS t1
    LEFT JOIN seasons AS t2
        ON t1.season_id = t2.season_id
),

sentinel AS (
    SELECT
        '-1'             AS game_sk,
        -1               AS game_id,
        99999999         AS season_id,
        'unknown'        AS season_label,
        FALSE            AS is_current_season,
        -1               AS game_type_id,
        'unknown'        AS game_type_name,
        'unknown'        AS game_number,
        NULL::DATE       AS game_date,
        NULL::TIMESTAMP  AS game_start_timestamp_et,
        NULL::TIMESTAMP  AS game_start_timestamp_utc,
        'unknown'        AS game_state,
        'unknown'        AS game_schedule_state,
        NULL::INT        AS regular_periods,
        NULL::INT        AS total_periods,
        'unknown'        AS outcome_last_period,
        'unknown'        AS special_event_name,
        FALSE            AS is_completed
)

SELECT * FROM final
UNION ALL
SELECT * FROM sentinel
