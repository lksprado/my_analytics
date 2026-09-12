{{
  config(
    tags = ['energia', 'marts'],
  )
}}

WITH
tab_energia AS (
    SELECT *
    FROM {{ ref('stg_solar_daily_energy') }}
),

tab_clima AS (
    SELECT *
    FROM {{ ref('stg_weather_daily') }}
),

final AS (
    SELECT
        t1.generation_date,
        t3.day_of_month,     
        t3.day_of_year,      
        t3.week_of_year,     
        t3.year_number,      
        t3.month_name,       
        t3.month_name_short, 
        t1.duration,
        t1.kwh,
        t1.max_kwh,
        t2.cloud_cover_afternoon,
        t2.humidity_afternoon,
        t2.precipitation_total,
        t2.temperature_min,
        t2.temperature_max,
        t2.temperature_afternoon,
        t2.temperature_night,
        t2.temperature_morning,
        t2.pressure_afternoon,
        t2.wind_max_speed,
        t2.wind_max_direction
    FROM tab_energia AS t1
    INNER JOIN tab_clima AS t2
        ON t1.generation_date = t2.weather_date
    INNER JOIN {{ref('dim_datas')}} t3
        ON t1.generation_date = t3.date_day
    WHERE t1.generation_date > DATE '2021-09-16'  -- data de instalação do sistema solar
)

SELECT * FROM final ORDER BY generation_date DESC
