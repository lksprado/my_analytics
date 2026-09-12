{{
  config(
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

SELECT
    mes_base,
    mes_final,
    pessoa,
    total_geral,
    total_disponibilidades,
    total_investido,
    bradesco,
    nubank,
    autocustodia,
    daycoval,
    avenue,
    wise,
    vlr_liquido_usd,
    CURRENT_TIMESTAMP AS model_updated_at
FROM {{ ref('carteira_agregada') }}
WHERE pessoa = 'lucas'
ORDER BY mes_final
