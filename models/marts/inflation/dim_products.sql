{{
  config(
    tags = ['inflacao'],
  )
}}

WITH
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
        product_name,
        LENGTH(product_name) AS num_name
    FROM {{ ref('stg_atacadao') }}
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
        product_name
    FROM reduced
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(["'atacadao'", "sku"]) }} AS product_sk,
        sku,
        category,
        brand_name,
        product_unity,
        ROUND(unity_value_normalized, 0) AS unity_value_normalized,
        unit_normalized,
        unity_type,
        unity_value,
        product_name,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at        
    FROM rank
    WHERE rn = 1
)

SELECT * FROM final
