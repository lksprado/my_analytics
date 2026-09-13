{{
  config(
    materialized = 'table',
    tags = ['nhl','staging', 'player_id'],
    post_hook = [
        "create index if not exists idx_players_id on {{ this }} (player_id)"
    ]
    )
}}

WITH
source AS (
    SELECT * FROM {{ source('nhl', 'nhl_raw_all_players') }}
),

regular AS (
    SELECT
        (payload ->> 'playerId')::INT                                                  AS player_id,
        (payload -> 'firstName' ->> 'default')                                         AS player_firstname,
        (payload -> 'lastName' ->> 'default')                                          AS player_lastname,
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
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'powerPlayPoints')::INT
            AS powerplay_points,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'gameWinningGoals')::INT
            AS game_winning_goals,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'shorthandedGoals')::INT
            AS shorthanded_goals,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'shorthandedPoints')::INT
            AS shorthanded_points,
        (payload -> 'careerTotals' -> 'regularSeason' ->> 'faceoffWinningPctg')::FLOAT
            AS faceoff_win_pctg,
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
        (payload ->> 'weightInKilograms')::INT                                         AS weight_kilogram,
        'regular'                                                                      AS season_type
    FROM source
    WHERE
        payload IS NOT NULL
        AND payload <> 'null'
),

playoffs AS (
    SELECT
        (payload ->> 'playerId')::INT                                             AS player_id,
        (payload -> 'firstName' ->> 'default')                                    AS player_firstname,
        (payload -> 'lastName' ->> 'default')                                     AS player_lastname,
        (payload ->> 'isActive')::BOOLEAN                                         AS is_active,
        (payload ->> 'position')                                                  AS position,
        (payload -> 'birthCity' ->> 'default')                                    AS birth_city,
        (payload ->> 'birthDate')::DATE                                           AS birthdate,
        (payload ->> 'birthCountry')                                              AS birth_country,
        (payload -> 'birthStateProvince' ->> 'default')                           AS birth_state_province,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'pim')::INT                  AS pim,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'goals')::INT                AS goals,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'shots')::INT                AS shots,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'avgToi')                    AS avg_toi,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'points')::INT               AS points,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'assists')::INT              AS assists,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'otGoals')::INT              AS overtime_goals,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'plusMinus')::INT            AS plus_minus,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'gamesPlayed')::INT          AS games_played,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'shootingPctg')::FLOAT       AS shooting_pctg,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'powerPlayGoals')::INT       AS powerplay_goals,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'powerPlayPoints')::INT      AS powerplay_points,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'gameWinningGoals')::INT     AS game_winning_goals,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'shorthandedGoals')::INT     AS shorthanded_goals,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'shorthandedPoints')::INT
            AS shorthanded_points,
        (payload -> 'careerTotals' -> 'playoffs' ->> 'faceoffWinningPctg')::FLOAT
            AS faceoff_win_pctg,
        (payload -> 'draftDetails' ->> 'year')::INT                               AS draft_year,
        (payload -> 'draftDetails' ->> 'round')::INT                              AS draft_round,
        (payload -> 'draftDetails' ->> 'teamAbbrev')                              AS draft_team_id,
        (payload -> 'draftDetails' ->> 'overallPick')::INT                        AS draft_overall_pick,
        (payload -> 'draftDetails' ->> 'pickInRound')::INT                        AS draft_pick_in_round,
        (payload -> 'fullTeamName' ->> 'default')                                 AS team_full_name,
        (payload ->> 'currentTeamId')::INT                                        AS current_team_id,
        (payload ->> 'shootsCatches')                                             AS shoots_catches,
        (payload ->> 'sweaterNumber')::INT                                        AS sweater_number,
        (payload ->> 'heightInInches')::INT                                       AS height_inches,
        (payload ->> 'weightInPounds')::INT                                       AS weight_pounds,
        (payload ->> 'heightInCentimeters')::INT                                  AS height_centimeters,
        (payload ->> 'weightInKilograms')::INT                                    AS weight_kilogram,
        'playoffs'                                                                AS season_type
    FROM source
    WHERE
        payload IS NOT NULL
        AND payload <> 'null'
),

union_tbs AS (
    SELECT * FROM regular
    UNION ALL
    SELECT * FROM playoffs
)

SELECT * FROM union_tbs
WHERE player_id IS NOT NULL
ORDER BY player_id DESC, season_type DESC
