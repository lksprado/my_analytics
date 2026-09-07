{{
  config(
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

{#- Recorte por pessoa do mart base `carteira`, que já resolve dim_datas, camada
    e fl_mes_atual. União por colunas nomeadas, não SELECT *: casar por posição
    já trocou camada por ativo em silêncio (ambas TEXT). -#}

SELECT
    mes_base,
    mes_final,
    trimestre,
    ano,
    pessoa,
    instituicao,
    emissor,
    conglomerado_fgc,
    classe_ativo,
    tipo_ativo,
    codigo_ativo,
    camada,
    ativo,
    indexador,
    data_vencimento,
    vencimento_em_dias,
    fl_vencido,
    vlr_atualizado_brl,
    moeda_ativo,
    fl_mes_atual,
    CURRENT_TIMESTAMP AS model_updated_at
FROM {{ ref('carteira') }}
WHERE pessoa = 'deusa'
ORDER BY mes_base, instituicao, classe_ativo, tipo_ativo, ativo
