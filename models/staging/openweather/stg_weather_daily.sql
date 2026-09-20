WITH
source AS (SELECT * FROM {{ source('openweather', 'openweather_daily') }}),

renamed AS (
    SELECT
        date::DATE                   AS weather_date,
        cloud_cover_afternoon::FLOAT AS cloud_cover_afternoon,
        humidity_afternoon::FLOAT    AS humidity_afternoon,
        precipitation_total::FLOAT   AS precipitation_total,
        temperature_min::FLOAT       AS temperature_min,
        temperature_max::FLOAT       AS temperature_max,
        temperature_afternoon::FLOAT AS temperature_afternoon,
        temperature_night::FLOAT     AS temperature_night,
        temperature_morning::FLOAT   AS temperature_morning,
        pressure_afternoon::FLOAT    AS pressure_afternoon,
        wind_max_speed::FLOAT        AS wind_max_speed,
        wind_max_direction::FLOAT    AS wind_max_direction,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM source
)

SELECT * FROM renamed
