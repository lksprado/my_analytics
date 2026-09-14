{{
  config(
    materialized = 'incremental',
    unique_key = ['game_sk', 'event_id'],
    incremental_strategy = 'delete+insert',
    tags = ['nhl'],
    post_hook = [
        "create index if not exists idx_fct_game_events on {{ this }} (game_sk, event_id)",
        "create index if not exists idx_fct_game_events_date on {{ this }} (game_date_sk)"
    ]
    )
}}

WITH
game_events AS (
    SELECT * FROM {{ ref('int_game_events') }}
    {% if is_incremental() %}
        -- reprocessa o último dia carregado para pegar jogos que ainda estavam em andamento
        WHERE game_date >= (SELECT TO_DATE(MAX(game_date_sk)::TEXT, 'YYYYMMDD') FROM {{ this }})
    {% endif %}
),

players AS (
    SELECT player_id, player_sk FROM {{ ref('dim_player') }}
),

final AS (
    SELECT
        t2.game_sk,
        TO_CHAR(t1.game_date, 'YYYYMMDD')::INT AS game_date_sk,
        t1.event_id,
        t1.event_order,
        t1.period_number,
        t1.period_type,
        t1.time_in_period_seconds,
        t1.event_type,
        t1.event_zone,
        t1.x_coord,
        t1.y_coord,
        COALESCE(t3.team_sk, '-1')             AS event_owner_team_sk,
        COALESCE(p1.player_sk, '-1')           AS shooting_player_sk,
        COALESCE(p2.player_sk, '-1')           AS goalie_in_net_player_sk,
        COALESCE(p3.player_sk, '-1')           AS hitting_player_sk,
        COALESCE(p4.player_sk, '-1')           AS hittee_player_sk,
        COALESCE(p5.player_sk, '-1')           AS faceoff_winning_player_sk,
        COALESCE(p6.player_sk, '-1')           AS faceoff_losing_player_sk,
        COALESCE(p7.player_sk, '-1')           AS penalty_committed_by_player_sk,
        COALESCE(p8.player_sk, '-1')           AS penalty_drawn_by_player_sk,
        t1.shot_type,
        t1.reason,
        t1.secondary_reason,
        t1.penalty_description,
        t1.penalty_type_code,
        t1.penalty_minutes,
        t1.home_score,
        t1.away_score
    FROM game_events AS t1
    INNER JOIN {{ ref('dim_game') }} AS t2
        ON t1.game_id = t2.game_id
    LEFT JOIN {{ ref('dim_team') }} AS t3
        ON t1.event_owner_team_id = t3.team_id
    LEFT JOIN players AS p1
        ON t1.shooting_player_id = p1.player_id
    LEFT JOIN players AS p2
        ON t1.goalie_in_net_player_id = p2.player_id
    LEFT JOIN players AS p3
        ON t1.hitting_player_id = p3.player_id
    LEFT JOIN players AS p4
        ON t1.hittee_player_id = p4.player_id
    LEFT JOIN players AS p5
        ON t1.faceoff_winning_player_id = p5.player_id
    LEFT JOIN players AS p6
        ON t1.faceoff_losing_player_id = p6.player_id
    LEFT JOIN players AS p7
        ON t1.penalty_committed_by_player_id = p7.player_id
    LEFT JOIN players AS p8
        ON t1.penalty_drawn_by_player_id = p8.player_id
)

SELECT * FROM final
