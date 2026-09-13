{{
  config(
    materialized = 'table',
    tags = ['nhl','staging', 'player_id'],
    post_hook = [
        "create index if not exists idx_fights on {{ this }} (fight_id)"
    ]
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
        {{ dbt_utils.generate_surrogate_key(['fight', 'date', 'gametime']) }} AS fight_id,
        fight                                                                 AS fight_desc,
        player_1_name,
        player_2_name,
        player_1_team,
        player_2_team,
        SPLIT_PART(SPLIT_PART(fight, '(', 2), ')', 1)                         AS team_1_code,
        SPLIT_PART(SPLIT_PART(fight, '(', 3), ')', 1)                         AS team_2_code,
        TO_DATE(date, 'MM/DD/YY')                                             AS game_date,
        period,
        gametime                                                              AS time_in_period,
        winner                                                                AS fight_winner,
        rating::FLOAT                                                         AS rating,
        vote_count::INT                                                       AS vote_count
    FROM source
),

dedup AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY fight_id) AS rn
    FROM renamed
),

final AS (
    SELECT
        fight_id,
        fight_desc,
        season_id,
        game_type_id,
        player_1_name,
        player_2_name,
        player_1_team,
        player_2_team,
        game_date,
        period,
        time_in_period,
        fight_winner,
        rating,
        vote_count,
        CASE
            WHEN team_1_code LIKE 'MON' THEN 'MTL'
            WHEN team_1_code LIKE 'WAS' THEN 'WSH'
            WHEN team_1_code LIKE 'CAL' THEN 'CGY'
            ELSE team_1_code
        END AS team_1_code,
        CASE
            WHEN team_2_code LIKE 'MON' THEN 'MTL'
            WHEN team_2_code LIKE 'WAS' THEN 'WSH'
            WHEN team_2_code LIKE 'CAL' THEN 'CGY'
            ELSE team_2_code
        END AS team_2_code
    FROM dedup
    WHERE rn = 1
)

SELECT * FROM final
