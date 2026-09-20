{{
  config(
    materialized = 'incremental',
    on_schema_change = 'append_new_columns',
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
        {%- set last_date_sk = run_query('SELECT MAX(game_date_sk) FROM ' ~ this).columns[0].values()[0] if execute else none %}
        -- reprocessa o último dia (jogos em andamento). Data como literal para o planner estimar certo e usar o índice;
        -- por isso o event_order é calculado aqui e não na view, senão a janela roda antes do filtro
        WHERE game_date >= TO_DATE('{{ last_date_sk }}', 'YYYYMMDD')
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
        ROW_NUMBER() OVER (PARTITION BY t1.game_id ORDER BY t1.sort_order)::INT AS event_order,
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
        t1.away_score,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
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
