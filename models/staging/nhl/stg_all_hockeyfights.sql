{{
  config(
    materialized = 'table',
    tags = ['nhl'],
    )
}}

WITH
source AS (
    SELECT * FROM {{ source('hockeyfights', 'hockeyfights_raw_all_fights') }}
),

renamed AS (
    SELECT
        REPLACE(season, '-', '')::INT                                         AS season_id,
        CASE
            WHEN season_type LIKE 'reg' THEN 2
            WHEN season_type LIKE 'pos' THEN 3
        END                                                                   AS game_type_id,
        LOWER(fight)                                                          AS description,
        REPLACE(LOWER(player_1_name),',', ' ')                                AS player_1_abbrev_name,
        REPLACE(LOWER(player_2_name),',', ' ')                                AS player_2_abbrev_name,
        LOWER(player_1_team)                                                  AS player_1_team_full_name,
        LOWER(player_2_team)                                                  AS player_2_team_full_name,
        SPLIT_PART(SPLIT_PART(fight, '(', 2), ')', 1)                         AS team_1_abbrev_name,
        SPLIT_PART(SPLIT_PART(fight, '(', 3), ')', 1)                         AS team_2_abbrev_name,
        TO_DATE(date, 'MM/DD/YY')                                             AS game_date,
        LOWER(period)                                                         AS period,
        gametime                                                              AS time_in_period,
        LOWER(winner)                                                         AS fight_winner_full_name,
        rating::FLOAT                                                         AS rating,
        vote_count::INT                                                       AS vote_count
    FROM source
),

dedup AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY description, game_date, time_in_period) AS rn
    FROM renamed
),

final AS (
    SELECT
        season_id,
        game_type_id,
        description,
        player_1_abbrev_name,
        player_2_abbrev_name,
        player_1_team_full_name,
        player_2_team_full_name,
        game_date,
        period,
        time_in_period,
        fight_winner_full_name,
        rating,
        vote_count,
        CASE
            WHEN team_1_abbrev_name LIKE 'MON' THEN 'MTL'
            WHEN team_1_abbrev_name LIKE 'WAS' THEN 'WSH'
            WHEN team_1_abbrev_name LIKE 'CAL' THEN 'CGY'
            ELSE team_1_abbrev_name
        END AS team_1_abbrev_name,
        CASE
            WHEN team_2_abbrev_name LIKE 'MON' THEN 'MTL'
            WHEN team_2_abbrev_name LIKE 'WAS' THEN 'WSH'
            WHEN team_2_abbrev_name LIKE 'CAL' THEN 'CGY'
            ELSE team_2_abbrev_name
        END AS team_2_abbrev_name
    FROM dedup
    WHERE rn = 1
)

SELECT * FROM final ORDER BY game_date DESC
