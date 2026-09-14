{{
  config(
    tags = ['nhl'],
    )
}}

WITH
pbp AS (
    SELECT * FROM {{ ref('stg_all_play_by_play') }}
    WHERE game_type_id IN (2, 3)
),

final AS (
    SELECT
        game_id,
        game_date,
        event_id,
        sort_order,
        period_number,
        LOWER(period_type)                                                                 AS period_type,
        SPLIT_PART(time_in_period, ':', 1)::INT * 60 + SPLIT_PART(time_in_period, ':', 2)::INT
            AS time_in_period_seconds,
        type_desc_key                                                                      AS event_type,
        CASE zone_code
            WHEN 'O' THEN 'offensive'
            WHEN 'N' THEN 'neutral'
            WHEN 'D' THEN 'defensive'
        END                                                                                AS event_zone,
        x_coord,
        y_coord,
        event_owner_team_id,
        shooting_player_id,
        goalie_in_net_player_id,
        hitting_player_id,
        hittee_player_id,
        winning_player_id                                                                  AS faceoff_winning_player_id,
        losing_player_id                                                                   AS faceoff_losing_player_id,
        commited_by_player_id                                                              AS penalty_committed_by_player_id,
        drawn_by_player_id                                                                 AS penalty_drawn_by_player_id,
        shot_type,
        reason,
        secondary_reason,
        desc_key                                                                           AS penalty_description,
        penalty_type_code,
        duration                                                                           AS penalty_minutes,
        home_score,
        away_score
    FROM pbp
)

SELECT * FROM final
