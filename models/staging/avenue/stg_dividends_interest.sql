{{
  config(
    tags = ['financas', 'staging'],
  )
}}

WITH
source AS (
    SELECT * FROM {{ source('avenue', 'dividends_interest') }}
),

renamed AS (
    SELECT
        debit::NUMERIC(18, 2)               AS debit,
        credit::NUMERIC(18, 2)              AS credit,
        person                              AS pessoa,
        TO_DATE(period_start, 'yyyy-MM-dd') AS period_start,
        TO_DATE(period_end, 'yyyy-MM-dd')   AS period_end
    FROM source
),

final AS (
    SELECT
        CASE
            WHEN period_end - period_start > 31 THEN DATE_TRUNC('month', period_end)
            ELSE period_start
        END::DATE      AS period_start,
        period_end,
        pessoa,
        'USD'          AS moeda_ativo,
        credit - debit AS vlr_liquido_usd,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM renamed
)

SELECT * FROM final
