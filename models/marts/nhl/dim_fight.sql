{{
  config(
    tags = ['nhl'],
    )
}}

WITH
fights AS (
    SELECT
        fight_id,
        season_id,
        game_type_id,
        description,
        player_1_abbrev_name,
        player_2_abbrev_name,
        player_1_team_full_name,
        player_2_team_full_name,
        team_1_abbrev_name,
        team_2_abbrev_name,
        game_date,
        period,
        time_in_period,
        fight_winner_full_name,
        rating,
        vote_count
    FROM {{ ref('stg_all_hockeyfights') }}
),

games AS (
    SELECT
        game_id,
        game_date,
        home_team_abbrev,
        away_team_abbrev
    FROM {{ ref('stg_all_games_details') }}
),

rosters AS (
    SELECT game_id, team_side, player_id FROM {{ ref('stg_all_games_details_skaters') }}
    UNION ALL
    SELECT game_id, team_side, player_id FROM {{ ref('stg_all_games_details_goalies') }}
),

rosters_named AS (
    SELECT
        t1.game_id,
        t1.team_side,
        t1.player_id,
        t2.abbrev_name
    FROM rosters AS t1
    INNER JOIN {{ ref('stg_all_players') }} AS t2
        ON t1.player_id = t2.id
),

-- time_in_period do hockeyfights diverge do play-by-play em alguns casos, por isso o jogo é casado só por data + times
fights_games AS (
    SELECT
        t1.fight_id,
        t2.game_id,
        CASE WHEN t2.home_team_abbrev = t1.team_1_abbrev_name THEN 'home' ELSE 'away' END AS team_1_side,
        CASE WHEN t2.home_team_abbrev = t1.team_2_abbrev_name THEN 'home' ELSE 'away' END AS team_2_side,
        t1.player_1_abbrev_name,
        t1.player_2_abbrev_name
    FROM fights AS t1
    INNER JOIN games AS t2
        ON t1.game_date = t2.game_date
        AND (
            (t1.team_1_abbrev_name = t2.home_team_abbrev AND t1.team_2_abbrev_name = t2.away_team_abbrev)
            OR (t1.team_1_abbrev_name = t2.away_team_abbrev AND t1.team_2_abbrev_name = t2.home_team_abbrev)
        )
),

fighters AS (
    SELECT fight_id, game_id, 1 AS fighter_number, team_1_side AS team_side, player_1_abbrev_name AS abbrev_name
    FROM fights_games
    UNION ALL
    SELECT fight_id, game_id, 2 AS fighter_number, team_2_side AS team_side, player_2_abbrev_name AS abbrev_name
    FROM fights_games
),

-- homônimos no mesmo time e jogo (ex.: irmãos Benn, Sutter) ficam sem player_id
fighters_matched AS (
    SELECT
        t1.fight_id,
        t1.fighter_number,
        CASE WHEN COUNT(DISTINCT t2.player_id) = 1 THEN MIN(t2.player_id) END AS player_id
    FROM fighters AS t1
    INNER JOIN rosters_named AS t2
        ON t1.game_id = t2.game_id
        AND t1.team_side = t2.team_side
        AND t1.abbrev_name = t2.abbrev_name
    GROUP BY
        t1.fight_id,
        t1.fighter_number
),

final AS (
    SELECT
        t1.fight_id,
        t2.game_id,
        t1.season_id,
        t1.game_type_id,
        t1.game_date,
        t1.period,
        t1.time_in_period,
        t1.description,
        t3.player_id AS player_1_id,
        t1.player_1_abbrev_name,
        t1.team_1_abbrev_name,
        t1.player_1_team_full_name,
        t4.player_id AS player_2_id,
        t1.player_2_abbrev_name,
        t1.team_2_abbrev_name,
        t1.player_2_team_full_name,
        t1.fight_winner_full_name,
        t1.rating,
        t1.vote_count
    FROM fights AS t1
    LEFT JOIN fights_games AS t2
        ON t1.fight_id = t2.fight_id
    LEFT JOIN fighters_matched AS t3
        ON t1.fight_id = t3.fight_id
        AND t3.fighter_number = 1
    LEFT JOIN fighters_matched AS t4
        ON t1.fight_id = t4.fight_id
        AND t4.fighter_number = 2
)

SELECT * FROM final
