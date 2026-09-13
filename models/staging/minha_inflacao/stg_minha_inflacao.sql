{{
  config(
    materialized = 'table',
    tags = ['inflacao', 'staging'],
  )
}}

WITH
source AS (
    SELECT * FROM {{ ref('seed_minha_inflacao') }}
),

renamed AS (
    SELECT
        (MAKE_DATE("Ano", "Mes", 1) + INTERVAL '1 month' - INTERVAL '1 day')::DATE     AS created_date,
        "Categoria"                                                                    AS category,
        "Produto"                                                                      AS product_name,
        "Unidade"                                                                      AS product_unity,
        "Qtd"                                                                          AS quantity,
        "Preço"                                                                        AS price,
        "Mês Atual"                                                                    AS current_month,
        "Mês passado"                                                                  AS past_month,
        "Var"                                                                          AS price_variation,
        "Peso"                                                                         AS weight,
        "Var Peso"                                                                     AS weight_variation,
        REGEXP_REPLACE({{ clean_string('"Produto"', 'lower') }}, '[^a-z0-9]', '', 'g') AS product_key
    FROM source
),

extracted AS (
    SELECT
        *,
        {{ dbt_utils.generate_surrogate_key(['product_key']) }} AS sk_product,
        {{ extract_product_unit('product_unity') }}             AS unit_token
    FROM renamed
),

final AS (
    SELECT
        created_date,
        sk_product,
        category,
        product_name,
        product_unity,
        {{ normalize_product_unit('unit_token') }},
        quantity,
        price,
        current_month,
        past_month,
        price_variation,
        weight,
        weight_variation
    FROM extracted
)

SELECT * FROM final
