{{
  config(
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
    banco_do_brasil,
    sofisa,
    itau,
    nubank,
    avenue,
    vlr_liquido_usd,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM {{ ref('carteira_agregada') }}
WHERE pessoa = 'jessica'
ORDER BY mes_final
