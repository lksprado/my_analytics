{{
  config(
    materialized = 'incremental',
    on_schema_change = 'append_new_columns',
    unique_key = 'game_id',
    tags = ['nhl', 'staging', 'game_id'],
    post_hook = [
        "create index if not exists idx_games_details on {{ this }} (game_id)"
    ]
  )
}}

WITH base AS (
    SELECT *
    FROM {{ ref('stg_base_all_games_details') }}
    {% if is_incremental() %}
        WHERE game_id > (
            SELECT COALESCE(MAX(game_id), 0)
            FROM {{ this }}
        )
    {% endif %}
),

flattening AS (
    SELECT
        game_id,
        season_id,
        game_type_id,
        game_date,
        game_state,
        regular_periods,
        game_outcome_last_period,
        game_outcome_total_periods,
        special_event_name,
        (game_start_timestamp_utc::TIMESTAMPTZ AT TIME ZONE 'UTC')::TIMESTAMP AS game_date_timestamp_utc,
        game_schedule_state,
        (payload -> 'awayTeam' ->> 'id')::INT                                 AS away_team_id,
        (payload -> 'awayTeam' ->> 'sog')::INT                                AS away_team_sog,
        (payload -> 'awayTeam' ->> 'score')::INT                              AS away_team_score,
        (payload -> 'homeTeam' ->> 'id')::INT                                 AS home_team_id,
        (payload -> 'homeTeam' ->> 'sog')::INT                                AS home_team_sog,
        (payload -> 'homeTeam' ->> 'score')::INT                              AS home_team_score,
        (payload -> 'awayTeam' ->> 'abbrev')                                  AS away_team_abbrev,
        (payload -> 'awayTeam' -> 'placeName' ->> 'default')                  AS away_team_placename,
        (payload -> 'awayTeam' -> 'commonName' ->> 'default')                 AS away_team_commonname,
        (payload -> 'awayTeam' ->> 'logo')                                    AS away_team_logo,
        (payload -> 'awayTeam' ->> 'darkLogo')                                AS away_team_darklogo,
        (payload -> 'homeTeam' ->> 'abbrev')                                  AS home_team_abbrev,
        (payload -> 'homeTeam' -> 'placeName' ->> 'default')                  AS home_team_placename,
        (payload -> 'homeTeam' -> 'commonName' ->> 'default')                 AS home_team_commonname,
        (payload -> 'homeTeam' ->> 'logo')                                    AS home_team_logo,
        (payload -> 'homeTeam' ->> 'darkLogo')                                AS home_team_darklogo
    FROM base
),

renamed AS (
    SELECT
        game_id,
        season_id,
        game_type_id,
        game_date,
        LOWER(game_state)                                                                                       AS game_state,
        regular_periods,
        LOWER(game_outcome_last_period)                                                                         AS game_outcome_last_period,
        game_outcome_total_periods,
        LOWER(special_event_name)                                                                               AS special_event_name,
        game_date_timestamp_utc,
        game_schedule_state,
        away_team_id,
        away_team_sog,
        away_team_score,
        home_team_id,
        home_team_sog,
        home_team_score,
        away_team_abbrev,
        NULLIF(REGEXP_REPLACE({{ clean_string('away_team_placename','lower') }}, '[^[:alpha:]. ]', '', 'g'), '') AS away_team_placename,
        REGEXP_REPLACE({{ clean_string('away_team_commonname','lower') }}, '[^[:alpha:]. ]', '', 'g')            AS away_team_commonname,
        away_team_logo,
        away_team_darklogo,
        home_team_abbrev,
        NULLIF(REGEXP_REPLACE({{ clean_string('home_team_placename','lower') }}, '[^[:alpha:]. ]', '', 'g'), '') AS home_team_placename,
        REGEXP_REPLACE({{ clean_string('home_team_commonname','lower') }}, '[^[:alpha:]. ]', '', 'g')            AS home_team_commonname,
        home_team_logo,
        home_team_darklogo,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM flattening
)

SELECT * FROM renamed
