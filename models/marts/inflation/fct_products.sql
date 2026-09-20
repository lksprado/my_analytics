{{
  config(
    tags = ['inflacao'],
  )
}}

WITH
final AS (
    SELECT DISTINCT
        t1.created_date,
        t2.product_sk,
        t1.high_price,
        t1.low_price,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM {{ ref('stg_atacadao') }} t1
    LEFT JOIN {{ ref('dim_products') }} t2
    ON t1.sku = t2.sku
)

SELECT * FROM final
