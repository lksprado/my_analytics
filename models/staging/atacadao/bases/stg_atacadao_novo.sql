{{
  config(
    materialized = 'ephemeral',
    tags = ['inflacao', 'staging'],
  )
}}

WITH
source AS (
    SELECT * FROM {{ source('atacadao', 'atacadao_raw') }}
),

renamed AS (
    SELECT
        to_date(extracted_at, 'yyyy-MM-dd') as created_at,
        sku,
        category,
        product_name,
        brand_name,
        high_price,
        low_price,
        CASE
        -- Com número + unidade no nome, vale a última ocorrência.
            WHEN
                REGEXP_COUNT(
                    LOWER(product_name),
                    '(\d+([.,]\d+)?\s*(mg|g|kg|ml|l|un|rolos|quilo|dúzias|dúzia|folhas))'
                ) > 0
                THEN REGEXP_SUBSTR(
                    LOWER(product_name),
                    '(\d+([.,]\d+)?\s*(mg|g|kg|ml|l|un|rolos|quilo|dúzias|dúzia|folhas))',
                    1,
                    REGEXP_COUNT(
                        LOWER(product_name),
                        '(\d+([.,]\d+)?\s*(mg|g|kg|ml|l|un|rolos|quilo|dúzias|dúzia|folhas))'
                    )
                )

            -- Sem número, unidade explícita conta como 1.
            WHEN LOWER(product_name) ~* '(^|\s)(un)(\s|$)'
                THEN 'un'
            WHEN LOWER(product_name) ~* '(^|\s)(maço)(\s|$)'
                THEN 'un'
            WHEN LOWER(product_name) ~* '(^|\s)(quilo)(\s|$)'
                THEN 'quilo'
        END                                 AS product_unity
    FROM source
),

units AS (
    SELECT
        *,
        CASE
            WHEN product_unity ~* '(kg|quilo|g|grama|g\\b)' THEN 'weight'
            WHEN product_unity ~* '(litro|l|l\\b|ml)' AND product_unity NOT LIKE '%folhas%' THEN 'volume'
            WHEN product_unity ~* '(un|folhas|dúzias|dúzia)' THEN 'unit'
            ELSE 'unknown'
        END AS quantity_type,
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
        END AS quantity_value_raw
    FROM renamed
    WHERE LOWER(category) IN ('bebidas', 'carnes, aves e peixes', 'frios e congelados', 'hortifrúti', 'limpeza', 'mercearia', 'padaria e matinais')
)

SELECT * FROM units
