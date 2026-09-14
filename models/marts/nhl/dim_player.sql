{{
  config(
    tags = ['nhl'],
    )
}}


WITH
player_info AS (
    SELECT
        t1.id,
        t1.full_name,
        t1.first_name,
        t1.last_name,
        t1.is_active,
        t1.position,
        t1.birth_country,
        t1.birth_city,
        t1.birthdate,
        t2.abbrev_name                               AS current_team_abbrev_name,
        t2.full_name                                 AS current_team_full_name,
        t2.place_name                                AS current_team_place_name,
        t2.common_name                               AS current_team_common_name,
        t1.height_centimeters,
        t1.height_inches,
        t1.weight_kilogram,
        t1.weight_pounds,
        COALESCE(t1.birth_state_province, 'unknown') AS birth_state_province,
        COALESCE(t1.draft_year, 9999)                AS draft_year,
        COALESCE(t1.draft_round, 9999)               AS draft_round,
        COALESCE(t1.draft_overall_pick, 9999)        AS draft_overall_pick,
        COALESCE(t1.draft_pick_in_round, 9999)       AS draft_pick_in_round,
        COALESCE(t1.shoots_catches, 'unknown')       AS shoots_catches
    FROM {{ ref('stg_all_players') }} AS t1
    LEFT JOIN {{ ref('dim_team') }} AS t2
        ON COALESCE(t1.current_team_id, -1) = t2.team_id

),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id', 'full_name']) }} AS player_sk,
        id                                                          AS player_id,
        full_name,
        first_name,
        last_name,
        is_active,
        position,
        birth_country,
        birth_state_province,
        birth_city,
        birthdate,
        draft_year,
        draft_round,
        draft_overall_pick,
        draft_pick_in_round,
        current_team_abbrev_name,
        current_team_full_name,
        current_team_place_name,
        current_team_common_name,
        shoots_catches,
        height_centimeters,
        height_inches,
        weight_kilogram,
        weight_pounds,
        FALSE                                                       AS is_inferred
    FROM player_info
),

-- jogadores do boxscore que a coleta de jogadores ainda não trouxe, para não perder linhas nos fatos
boxscore_players AS (
    SELECT DISTINCT ON (player_id)
        player_id,
        LOWER(player_name) AS full_name,
        position
    FROM (
        SELECT game_id, player_id, player_name, position FROM {{ ref('stg_all_games_details_skaters') }}
        UNION ALL
        SELECT game_id, player_id, player_name, position FROM {{ ref('stg_all_games_details_goalies') }}
    ) AS boxscore
    ORDER BY player_id, game_id DESC
),

inferred AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['t1.player_id', 't1.full_name']) }} AS player_sk,
        t1.player_id,
        t1.full_name,
        'unknown'                                                             AS first_name,
        'unknown'                                                             AS last_name,
        FALSE                                                                 AS is_active,
        t1.position,
        'unknown'                                                             AS birth_country,
        'unknown'                                                             AS birth_state_province,
        'unknown'                                                             AS birth_city,
        NULL::DATE                                                            AS birthdate,
        9999                                                                  AS draft_year,
        9999                                                                  AS draft_round,
        9999                                                                  AS draft_overall_pick,
        9999                                                                  AS draft_pick_in_round,
        'unknown'                                                             AS current_team_abbrev_name,
        'unknown'                                                             AS current_team_full_name,
        'unknown'                                                             AS current_team_place_name,
        'unknown'                                                             AS current_team_common_name,
        'unknown'                                                             AS shoots_catches,
        NULL::INT                                                             AS height_centimeters,
        NULL::INT                                                             AS height_inches,
        NULL::INT                                                             AS weight_kilogram,
        NULL::INT                                                             AS weight_pounds,
        TRUE                                                                  AS is_inferred
    FROM boxscore_players AS t1
    WHERE NOT EXISTS (SELECT 1 FROM final AS t2 WHERE t2.player_id = t1.player_id)
),

sentinel AS (
    SELECT
        '-1'       AS player_sk,
        -1         AS player_id,
        'unknown'  AS full_name,
        'unknown'  AS first_name,
        'unknown'  AS last_name,
        FALSE      AS is_active,
        'unknown'  AS position,
        'unknown'  AS birth_country,
        'unknown'  AS birth_state_province,
        'unknown'  AS birth_city,
        NULL::DATE AS birthdate,
        9999       AS draft_year,
        9999       AS draft_round,
        9999       AS draft_overall_pick,
        9999       AS draft_pick_in_round,
        'unknown'  AS current_team_abbrev_name,
        'unknown'  AS current_team_full_name,
        'unknown'  AS current_team_place_name,
        'unknown'  AS current_team_common_name,
        'unknown'  AS shoots_catches,
        NULL::INT  AS height_centimeters,
        NULL::INT  AS height_inches,
        NULL::INT  AS weight_kilogram,
        NULL::INT  AS weight_pounds,
        FALSE      AS is_inferred
)

SELECT * FROM final
UNION ALL
SELECT * FROM inferred
UNION ALL
SELECT * FROM sentinel
