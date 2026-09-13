{{
  config(
    materialized = 'table',
    tags = ['inflacao', 'staging'],
  )
}}

WITH
source_1 AS (
    SELECT * FROM {{ ref('stg_atacadao_historico') }}
),

source_2 AS (
    SELECT * FROM {{ ref('stg_atacadao_novo') }}
),

unioned AS (
    SELECT * FROM source_1
    UNION ALL
    SELECT * FROM source_2
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
        product_unity,
        unity_type,
        unity_value,

        CASE
            WHEN REGEXP_REPLACE(LOWER(product_unity), '[0-9.,\s]', '', 'g') IN ('kg', 'quilo', 'quilos') THEN 'kilogram'
            WHEN REGEXP_REPLACE(LOWER(product_unity), '[0-9.,\s]', '', 'g') IN ('g', 'grama', 'gramas') THEN 'gram'
            WHEN REGEXP_REPLACE(LOWER(product_unity), '[0-9.,\s]', '', 'g') IN ('ml') THEN 'millilitre'
            WHEN REGEXP_REPLACE(LOWER(product_unity), '[0-9.,\s]', '', 'g') IN ('l', 'litro', 'litros') THEN 'litre'
            WHEN REGEXP_REPLACE(LOWER(product_unity), '[0-9.,\s]', '', 'g') IN ('un', 'uni', 'unid', 'unidade', 'unidades', 'rolos', 'dúzias', 'folhas') THEN 'unity'
        END                                        AS unit_normalized
    FROM unioned

)

SELECT * FROM renamed
WHERE unit_normalized IS NOT NULL
ORDER BY created_date DESC
