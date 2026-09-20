{{
  config(
    tags = ['nhl','staging', 'game_id'],
    post_hook = [
        "create index if not exists idx_games_summary on {{ this }} (game_id)"
    ]
    )
}}

WITH
source AS (
    SELECT * FROM {{ source('nhl', 'nhl_raw_all_games_summary') }}
),

renamed AS (
    SELECT
        (payload ->> 'id')::INT                       AS game_id,
        (payload ->> 'season')::INT                   AS season_id,
        (payload ->> 'gameDate')::DATE                AS game_date,
        (payload ->> 'gameType')::INT                 AS game_type_id,
        (payload ->> 'homeScore')::INT                AS home_score,
        (payload ->> 'homeTeamId')::INT               AS home_team_id,
        (payload ->> 'gameStateId')::INT              AS game_state_id,
        (payload ->> 'visitingScore')::INT            AS visiting_score,
        (payload ->> 'visitingTeamId')::INT           AS visiting_team_id,
        (payload ->> 'easternStartTime')::TIMESTAMP   AS game_start_timestamp_et,
        (payload ->> 'gameScheduleStateId')::INT      AS game_schedule_state_id,
        (payload ->> 'gameNumber')                    AS game_number,
        (payload ->> 'period')                        AS period,
        CASE
            WHEN payload ->> 'gameType' LIKE '1' THEN 'preseason'
            WHEN payload ->> 'gameType' LIKE '2' THEN 'regular'
            WHEN payload ->> 'gameType' LIKE '3' THEN 'playoffs'
        END                                           AS game_type_name,
        (payload ->> 'gameDate')::DATE < CURRENT_DATE AS has_happened_by_time,
        (payload ->> 'gameStateId')::INT = 7          AS has_happened_by_status,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM source
    WHERE (payload ->> 'gameScheduleStateId')::INT = 1
)

SELECT * FROM renamed
