{{
  config(
    materialized = 'table',
    tags = ['nhl','staging']
    )
}}

WITH
source AS (
    SELECT
        (payload ->> 'id')::INT          AS id,
        (payload ->> 'franchiseId')::INT AS franchise_id,
        (payload ->> 'triCode')          AS abbrev_name,
        (payload ->> 'fullName')         AS full_name
    FROM {{ source('nhl', 'nhl_raw_all_teams_id') }}
    WHERE (payload ->> 'id')::INT <> 70
),

renamed AS (
    SELECT 
        id,
        franchise_id,
        abbrev_name,
        REGEXP_REPLACE({{ clean_string('full_name','lower') }}, '[^[:alpha:]. ]', '', 'g') AS full_name
    FROM source
)

SELECT * FROM renamed
