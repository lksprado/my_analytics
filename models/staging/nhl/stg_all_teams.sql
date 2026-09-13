{{
  config(
    materialized = 'table',
    tags = ['nhl','staging']
    )
}}

WITH
source AS (
    SELECT * FROM {{ source('nhl', 'nhl_raw_all_teams_id') }}
),

renamed AS (
    SELECT
        (payload ->> 'id')::INT          AS team_id,
        (payload ->> 'franchiseId')::INT AS franchise_id,
        (payload ->> 'triCode')          AS team_code,
        (payload ->> 'fullName')         AS team_fullname
    FROM source
    WHERE (payload ->> 'id')::INT <> 70
)

SELECT * FROM renamed
