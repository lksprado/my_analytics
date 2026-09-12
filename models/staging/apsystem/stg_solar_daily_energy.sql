WITH
source AS (SELECT * FROM {{ source('apsystem', 'solar_daily_energy') }}),

renamed AS (
    SELECT
        date::DATE    AS generation_date,
        duration::INT AS duration,
        total::FLOAT  AS kwh,
        co2::FLOAT,
        max::FLOAT    AS max_kwh
    FROM source
)

SELECT * FROM renamed
