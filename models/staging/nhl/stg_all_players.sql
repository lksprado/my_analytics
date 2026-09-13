{{
  config(
    materialized = 'table',
    tags = ['nhl','staging', 'id'],
    post_hook = [
        "create index if not exists idx_players_id on {{ this }} (id)"
    ]
    )
}}

WITH
source AS (
    SELECT
        (payload ->> 'playerId')::INT                                                  AS id,
        (payload -> 'firstName' ->> 'default')                                         AS first_name,
        (payload -> 'lastName' ->> 'default')                                          AS last_name,
        (payload ->> 'isActive')::BOOLEAN                                              AS is_active,
        (payload ->> 'position')                                                       AS position,
        (payload -> 'birthCity' ->> 'default')                                         AS birth_city,
        (payload ->> 'birthDate')::DATE                                                AS birthdate,
        (payload ->> 'birthCountry')                                                   AS birth_country,
        (payload -> 'birthStateProvince' ->> 'default')                                AS birth_state_province,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'pim')::INT                  AS pim,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'goals')::INT                AS goals,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'shots')::INT                AS shots,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'avgToi')                    AS avg_toi,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'points')::INT               AS points,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'assists')::INT              AS assists,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'otGoals')::INT              AS overtime_goals,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'plusMinus')::INT            AS plus_minus,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'gamesPlayed')::INT          AS games_played,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'shootingPctg')::FLOAT       AS shooting_pctg,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'powerPlayGoals')::INT       AS powerplay_goals,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'powerPlayPoints')::INT      AS powerplay_points,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'gameWinningGoals')::INT     AS game_winning_goals,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'shorthandedGoals')::INt     AS shorthanded_goals,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'shorthandedPoints')::INT    AS shorthanded_points,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'faceoffWinningPctg')::FLOAT AS faceoff_win_pctg,
        (payload -> 'draftDetails' ->> 'year')::INT                                    AS draft_year,
        (payload -> 'draftDetails' ->> 'round')::INT                                   AS draft_round,
        (payload -> 'draftDetails' ->> 'teamAbbrev')                                   AS draft_team_id,
        (payload -> 'draftDetails' ->> 'overallPick')::INT                             AS draft_overall_pick,
        (payload -> 'draftDetails' ->> 'pickInRound')::INT                             AS draft_pick_in_round,
        (payload -> 'fullTeamName' ->> 'default')                                      AS team_full_name,
        (payload ->> 'currentTeamId')::INT                                             AS current_team_id,
        (payload ->> 'shootsCatches')                                                  AS shoots_catches,
        (payload ->> 'sweaterNumber')::INT                                             AS sweater_number,
        (payload ->> 'heightInInches')::INT                                            AS height_inches,
        (payload ->> 'weightInPounds')::INT                                            AS weight_pounds,
        (payload ->> 'heightInCentimeters')::INT                                       AS height_centimeters,
        (payload ->> 'weightInKilograms')::INT                                         AS weight_kilogram
    FROM {{ source('nhl', 'nhl_raw_all_players') }}
    WHERE
        payload IS NOT NULL
        AND payload <> 'null'
    
),
renamed AS (
    SELECT 
        id,
        CONCAT(LOWER(LEFT(first_name,1)), '.', ' ',  LOWER(last_name)) AS abbrev_name,
        CONCAT(LOWER(first_name), ' ', LOWER(last_name)) AS full_name,
        LOWER(first_name) AS first_name,
        LOWER(last_name) AS last_name,
        is_active,
        position,
        LOWER(birth_city) AS birth_city,
        birthdate,
        birth_country,
        LOWER(birth_state_province) AS birth_state_province,
        pim,
        goals,
        shots,
        avg_toi,
        points,
        assists,
        overtime_goals,
        plus_minus,
        games_played,
        shooting_pctg,
        powerplay_goals,
        powerplay_points,
        game_winning_goals,
        shorthanded_goals,
        shorthanded_points,
        faceoff_win_pctg,
        draft_year,
        draft_round,
        draft_team_id AS draft_team_abbrev_name,
        draft_overall_pick,
        draft_pick_in_round,
        LOWER(team_full_name) AS team_full_name,
        current_team_id,
        shoots_catches,
        sweater_number,
        height_inches,
        weight_pounds,
        height_centimeters,
        weight_kilogram
    FROM source
)
SELECT * FROM renamed
WHERE id IS NOT NULL
ORDER BY id DESC
