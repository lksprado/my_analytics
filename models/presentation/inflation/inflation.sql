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
        fct.sku,
        dim.product_name,
        dim.category,
        dim.brand_name,
        dim.product_unity,
        dim.unit_normalized,
        dim.unity_type,
        dim.unity_value_normalized,
        fct.high_price,
        fct.low_price
    FROM
        fct
    INNER JOIN dim
        ON fct.sku = dim.sku
)

SELECT * FROM final
ORDER BY
    created_date ASC,
    sku DESC
