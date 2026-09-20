{{
  config(
    tags = ['nhl'],
    )
}}

WITH

game_details AS (
    SELECT
        home_team_id                                                                  AS id,
        STRING_AGG(DISTINCT home_team_logo, ', ' ORDER BY home_team_logo)             AS logo,
        STRING_AGG(DISTINCT home_team_darklogo, ', ' ORDER BY home_team_darklogo)     AS darklogo,
        STRING_AGG(DISTINCT home_team_placename, ', ' ORDER BY home_team_placename)
            AS place_name,
        STRING_AGG(DISTINCT home_team_commonname, ', ' ORDER BY home_team_commonname)
            AS common_name,
        MAX(season_id)                                                                AS latest_season_id,
        MIN(season_id)                                                                AS first_season_id
    FROM {{ ref('stg_all_games_details') }}
    GROUP BY home_team_id
),

teams AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['t1.id', 't1.abbrev_name']) }} AS team_sk,
        t1.id                                                               AS team_id,
        t1.franchise_id,
        t1.abbrev_name,
        t1.full_name,
        t2.place_name,
        t2.common_name,
        LEFT(t2.first_season_id::TEXT, 4)::INT                              AS first_season_year,
        RIGHT(t2.latest_season_id::TEXT, 4)::INT                            AS latest_season_year,
        t2.first_season_id,
        t2.latest_season_id,
        t3.is_current                                                       AS is_active,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM {{ ref('stg_all_teams') }} AS t1
    LEFT JOIN game_details AS t2
        ON t1.id = t2.id
    LEFT JOIN {{ ref('vw_stg_request_seasons_id') }} AS t3
        ON t2.latest_season_id = t3.season_id
    LEFT JOIN {{ ref('vw_stg_request_seasons_id') }} AS t4
        ON t2.first_season_id = t4.season_id
    WHERE t1.id < 99
),

sentinel AS (
    SELECT
        '-1'      AS team_sk,
        -1        AS team_id,
        -1        AS franchise_id,
        'unknown' AS abbrev_name,
        'unknown' AS full_name,
        'unknown' AS place_name,
        'unknown' AS common_name,
        9999      AS first_season_year,
        9999      AS latest_season_year,
        99999999  AS first_season_id,
        99999999  AS latest_season_id,
        FALSE     AS is_active,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
)

SELECT * FROM teams
UNION ALL
SELECT * FROM sentinel
