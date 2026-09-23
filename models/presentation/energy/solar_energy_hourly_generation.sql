{{
  config(
    tags = ['energia', 'marts'],
  )
}}

WITH
tab_energia_hora AS (
    SELECT
        t1.generated_at,
        t1.generation_date,
        t2.day_of_month,
        t2.day_of_year,
        t2.week_of_year,
        t2.year_number,
        t2.month_name,
        t2.month_name_short,
        t1.kwh,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM {{ ref('stg_solar_hourly_energy') }} t1
    INNER JOIN {{ref('dim_dates')}} t2
        ON t1.generation_date = t2.date_day
)

SELECT * FROM tab_energia_hora ORDER BY generation_date DESC, generated_at ASC
