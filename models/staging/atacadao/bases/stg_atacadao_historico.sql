{{
  config(
    materialized = 'ephemeral',
    tags = ['inflacao', 'staging'],
  )
}}

WITH
source AS (
    SELECT * FROM {{ ref('seed_atacadao_historico') }}
),

renamed AS (
    SELECT
        date_scrapped AS created_date,
        sku,
        category,
        product_name,
        brand_name,
        high_price,
        low_price,
        LOWER(CASE
            WHEN REGEXP_COUNT(product_name, ' com ') = 1
                THEN SPLIT_PART(product_name, ' com ', 2)

            WHEN REGEXP_COUNT(product_name, ' com ') >= 2
                THEN SPLIT_PART(product_name, ' com ', 3)
        END)          AS product_unity
    FROM source
),

units AS (
    SELECT
        *,
        CASE
            WHEN product_unity ~* '(kg|quilo|g|grama|g\\b)' THEN 'weight'
            WHEN product_unity ~* '(litro|l|l\\b|ml)' THEN 'volume'
            WHEN product_unity ~* '(un)' THEN 'unit'
            ELSE 'unknown'
        END AS unity_type,
        CASE
            WHEN product_unity ~* '^(kg|quilo|litro|l|ml)$' THEN 1::NUMERIC

            WHEN product_unity ~* '[0-9]'
                THEN
                    REPLACE(
                        REGEXP_REPLACE(product_unity, '[^0-9.,]', '', 'g'),
                        ',',
                        '.'
                    )::NUMERIC

            ELSE 1
        END AS unity_value
    FROM renamed
    WHERE LOWER(category) IN ('bebidas', 'carnes, aves e peixes', 'frios e congelados', 'hortifrúti', 'limpeza', 'mercearia', 'padaria e matinais')
)

SELECT * FROM units
