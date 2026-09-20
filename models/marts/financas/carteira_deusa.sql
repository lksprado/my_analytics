{{
  config(
    tags = ['financas', 'marts'],
  )
}}

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
    fonte_dado,
    fl_mes_atual,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM {{ ref('carteira') }}
WHERE pessoa = 'deusa'
ORDER BY mes_base, instituicao, classe_ativo, tipo_ativo, ativo
