{{
  config(
    materialized = 'ephemeral',
    tags = ['nhl', 'staging', 'game_id']
  )
}}

WITH source AS (
    SELECT payload
    FROM {{ source('nhl', 'nhl_raw_all_games_details') }}
),

base_fields AS (
    SELECT
        payload,
        (payload ->> 'id')::INT                             AS game_id,
        (payload ->> 'season')::INT                         AS season_id,
        (payload ->> 'gameType')::INT                       AS game_type_id,
        (payload ->> 'gameDate')::DATE                      AS game_date,
        (payload ->> 'regPeriods')::INT                     AS regular_periods,
        (payload -> 'periodDescriptor' ->> 'number')::INT   AS game_outcome_total_periods,
        (payload ->> 'gameState')                           AS game_state,
        (payload -> 'gameOutcome' ->> 'lastPeriodType')     AS game_outcome_last_period,
        (payload -> 'specialEvent' -> 'name' ->> 'default') AS special_event_name,
        (payload ->> 'startTimeUTC')                        AS game_start_timestamp_utc,
        (payload ->> 'gameScheduleState')                   AS game_schedule_state
    FROM source
    WHERE (payload ->> 'id') IS NOT NULL
)

SELECT * FROM base_fields
