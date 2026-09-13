{{
  config(
    materialized = 'incremental',
    unique_key = ['game_id', 'event_id'],
    incremental_strategy = 'delete+insert',
    tags = ['nhl','staging', 'game_id'],
    post_hook = [
        "create index if not exists idx_games_pbp on {{ this }} (game_id, event_id)",
        "create index if not exists idx_pbp_game_date on {{ this }} (game_date, game_id)"
    ]
    )
}}

WITH
source AS (
    SELECT * FROM {{ source('nhl', 'nhl_raw_all_play_by_play') }}
    {% if is_incremental() %}
        where (payload ->> 'gameDate')::date > (select max(game_date) from {{ this }})
    {% endif %}
),

renamed AS (
    SELECT
        (payload ->> 'id')::INT                            AS game_id,
        (payload ->> 'season')::INT                        AS season_id,
        (payload -> 'clock' ->> 'running')::BOOLEAN        AS is_running,
        (payload -> 'clock' ->> 'inIntermission')::BOOLEAN AS is_in_intermission,
        (payload ->> 'otInUse')::BOOLEAN                   AS overtime_in_use,
        (payload ->> 'gameDate')::DATE                     AS game_date,
        (payload ->> 'gameType')::INT                      AS game_type_id,
        (payload ->> 'maxPeriods')::INT                    AS max_periods,
        (payload ->> 'regPeriods')::INT                    AS reg_periods,
        (payload ->> 'startTimeUTC')::TIMESTAMP            AS start_time_utc,
        (payload ->> 'shootoutInUse')::BOOLEAN             AS shootout_in_use,
        (p ->> 'eventId')::INT                             AS event_id,
        (p ->> 'typeCode')::INT                            AS type_code,
        (p ->> 'sortOrder')::INT                           AS sort_order,
        (p ->> 'situationCode')::INT                       AS situation_code,
        (p -> 'periodDescriptor' ->> 'number')::INT        AS period_number,
        (p -> 'details' ->> 'xCoord')::INT                 AS x_coord,
        (p -> 'details' ->> 'yCoord')::INT                 AS y_coord,
        (p -> 'details' ->> 'duration')::INT               AS duration,
        (p -> 'details' ->> 'drawnByPlayerId')::INT        AS drawn_by_player_id,
        (p -> 'details' ->> 'eventOwnerTeamId')::INT       AS event_owner_team_id,
        (p -> 'details' ->> 'committedByPlayerId')::INT    AS commited_by_player_id,
        (p -> 'details' ->> 'hitteePlayerId')::INT         AS hittee_player_id,
        (p -> 'details' ->> 'hittingPlayerId')::INT        AS hitting_player_id,
        (p -> 'details' ->> 'losingPlayerId')::INT         AS losing_player_id,
        (p -> 'details' ->> 'winningPlayerId')::INT        AS winning_player_id,
        (p -> 'details' ->> 'awaySOG')::INT                AS away_sog,
        (p -> 'details' ->> 'homeSOG')::INT                AS home_sog,
        (p -> 'details' ->> 'goalieInNetId')::INT          AS goalie_in_net_player_id,
        (p -> 'details' ->> 'shootingPlayerId')::INT       AS shooting_player_id,
        (p -> 'details' ->> 'awayScore')::INT              AS away_score,
        (p -> 'details' ->> 'homeScore')::INT              AS home_score,
        (payload -> 'clock' ->> 'timeRemaining')           AS time_remaining,
        (payload -> 'clock' ->> 'secondsRemaining')        AS seconds_remaining,
        (payload ->> 'gameState')                          AS game_state,
        (payload -> 'gameOutcome' ->> 'lastPeriodType')    AS outcome_last_period_type,
        (payload ->> 'gameScheduleState')                  AS game_schedule_state,
        (p ->> 'typeDescKey')                              AS type_desc_key,
        (p ->> 'timeInPeriod')                             AS time_in_period,
        (p -> 'periodDescriptor' ->> 'periodType')         AS period_type,
        (p ->> 'homeTeamDefendingSide')                    AS home_team_defending_side,
        (p -> 'details' ->> 'descKey')                     AS desc_key,
        (p -> 'details' ->> 'typeCode')                    AS penalty_type_code,
        (p -> 'details' ->> 'zoneCode')                    AS zone_code,
        (p -> 'details' ->> 'reason')                      AS reason,
        (p -> 'details' ->> 'secondaryReason')             AS secondary_reason,
        (p -> 'details' ->> 'shotType')                    AS shot_type
    FROM source,
        JSONB_ARRAY_ELEMENTS(payload -> 'plays') AS p
)

SELECT * FROM renamed
