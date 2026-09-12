WITH
source AS (SELECT * FROM {{ source('apsystem', 'solar_hourly_energy') }}),

renamed AS (
    SELECT
        datetime::DATE      AS generation_date,
        datetime::TIMESTAMP AS generated_at,
        energy::FLOAT       AS kwh
    FROM source
)

SELECT * FROM renamed
