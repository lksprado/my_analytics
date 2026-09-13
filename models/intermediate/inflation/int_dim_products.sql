{{
  config(
    materialized = 'view',
    tags = ['inflacao', 'intermediate'],
  )
}}

WITH
source AS (
    SELECT * FROM {{ ref('stg_atacadao') }}
),

reduced AS (
    SELECT DISTINCT
        sku,
        category,
        product_unity,
        unit_normalized,
        brand_name,
        unity_type,
        unity_value,
        unity_value_normalized,
        LOWER(product_name)  AS product_name,
        LENGTH(product_name) AS num_name
    FROM source
),

rank AS (
    SELECT
        sku,
        category,
        product_unity,
        unit_normalized,
        brand_name,
        unity_type,
        unity_value,
        unity_value_normalized,
        ROW_NUMBER() OVER (PARTITION BY sku ORDER BY num_name DESC) AS rn,
        TRIM(
            REGEXP_REPLACE(
                LOWER(product_name),
                '\s*\d+(\.\d+)?\s*(mg|g|kg|ml|l|un)$',
                ''
            )
        )                                                           AS product_name
    FROM reduced
),

final AS (
    SELECT
        sku,
        category,
        brand_name,
        product_unity,
        unit_normalized,
        unity_type,
        unity_value,
        REPLACE(TRIM(
            REGEXP_REPLACE(
                product_name,
                '\s+com$',
                ''
            )
        ), ',', '')                      AS product_name,
        ROUND(unity_value_normalized, 3) AS unity_value_normalized
    FROM rank
    WHERE rn = 1
)

SELECT * FROM final
