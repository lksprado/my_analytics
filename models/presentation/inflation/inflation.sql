{{
  config(
    tags = ['inflacao','marts'],
    )
}}

WITH
dim AS (
    SELECT * FROM {{ ref('dim_products') }}
),

fct AS (
    SELECT * FROM {{ ref('fct_products') }}
),

final AS (
    SELECT
        fct.created_date,
        dim.product_name,
        dim.category,
        dim.brand_name,
        dim.product_unity,
        dim.unity_value_normalized,
        dim.unit_normalized,
        dim.unity_type,
        fct.high_price,
        fct.low_price,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM
        fct
    INNER JOIN dim
        ON fct.product_sk = dim.product_sk
)

SELECT * FROM final
ORDER BY
    created_date DESC
