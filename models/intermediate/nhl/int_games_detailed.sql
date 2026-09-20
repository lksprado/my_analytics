{{
  config(
    tags = ['nhl'],
    )
}}

with
game_summary as (
    select * from {{ ref('stg_all_games_summary') }}
    where game_type_id in (2, 3)
),

game_details as (
    select * from {{ ref('stg_all_games_details') }}
),

renamed as (
    select
        gs.game_id,
        gs.game_number,
        gs.season_id,
        gs.game_date,
        gs.game_type_id,
        gs.game_type_name,
        gs.game_start_timestamp_et,
        gs.home_team_id,
        gs.visiting_team_id as away_team_id,
        gs.home_score,
        gs.visiting_score as away_score,
        gs.has_happened_by_status,
        gs.has_happened_by_time,
        gd.game_state,
        gd.regular_periods,
        gd.game_outcome_last_period,
        gd.game_outcome_total_periods,
        gd.special_event_name,
        gd.game_date_timestamp_utc,
        gd.game_schedule_state,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    from game_summary as gs
    left join game_details as gd
        on gs.game_id = gd.game_id
)

select * from renamed
