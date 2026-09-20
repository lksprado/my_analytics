{{
  config(
    tags = ['financas', 'staging'],
  )
}}

WITH
source AS (
    SELECT * FROM {{ source('google_finance_sheet', 'ajuste') }}
),

renamed AS (
    SELECT
        REGEXP_REPLACE(ajuste_feito, '[^0-9]', '', 'g')::INT AS ajuste_realizado,

        para                                                 AS pessoa,
        TO_DATE(
            CASE
                WHEN mes LIKE 'jan.%' THEN '01/' || RIGHT(mes, 2)
                WHEN mes LIKE 'fev.%' THEN '02/' || RIGHT(mes, 2)
                WHEN mes LIKE 'mar.%' THEN '03/' || RIGHT(mes, 2)
                WHEN mes LIKE 'abr.%' THEN '04/' || RIGHT(mes, 2)
                WHEN mes LIKE 'mai.%' THEN '05/' || RIGHT(mes, 2)
                WHEN mes LIKE 'jun.%' THEN '06/' || RIGHT(mes, 2)
                WHEN mes LIKE 'jul.%' THEN '07/' || RIGHT(mes, 2)
                WHEN mes LIKE 'ago.%' THEN '08/' || RIGHT(mes, 2)
                WHEN mes LIKE 'set.%' THEN '09/' || RIGHT(mes, 2)
                WHEN mes LIKE 'out.%' THEN '10/' || RIGHT(mes, 2)
                WHEN mes LIKE 'nov.%' THEN '11/' || RIGHT(mes, 2)
                WHEN mes LIKE 'dez.%' THEN '12/' || RIGHT(mes, 2)
            END, 'MM/YY'
        )                                                    AS mes,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM source
)

SELECT * FROM renamed
