{{
  config(
    materialized = 'table',
    tags = ['inflacao', 'staging'],
  )
}}

WITH
historico AS (
    SELECT
        date_scrapped AS created_date,
        sku,
        category,
        product_name,
        brand_name,
        high_price,
        low_price
    FROM {{ ref('seed_atacadao_historico') }}
),

novo AS (
    SELECT
        TO_DATE(extracted_at, 'yyyy-MM-dd') AS created_date,
        sku,
        category,
        product_name,
        brand_name,
        high_price,
        low_price
    FROM {{ source('atacadao', 'atacadao_raw') }}
),

unioned AS (
    SELECT * FROM historico
    UNION ALL
    SELECT * FROM novo
),

renamed AS (
    SELECT
        created_date,
        sku,
        {{ clean_string('category', 'lower') }}     AS category,
        {{ clean_string('product_name', 'lower') }} AS product_name,
        {{ clean_string('brand_name', 'lower') }}   AS brand_name,
        high_price,
        low_price,
        {{ extract_product_unit('product_name') }}  AS product_unity
    FROM unioned
    WHERE LOWER(category) IN ('bebidas', 'carnes, aves e peixes', 'frios e congelados', 'hortifrúti', 'limpeza', 'mercearia', 'padaria e matinais')
),

final AS (
    SELECT
        *,
        {{ normalize_product_unit('product_unity') }}
    FROM renamed
)

SELECT * FROM final
WHERE unit_normalized IS NOT NULL
