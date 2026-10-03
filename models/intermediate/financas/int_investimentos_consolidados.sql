{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}

WITH
relatorio AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        emissor,
        classe_ativo,
        tipo_ativo,
        codigo_ativo,
        ativo,
        indexador,
        data_vencimento,
        vencimento_em_dias,
        fl_vencido,
        vlr_atualizado_brl,
        moeda_ativo,
        fonte_dado
    FROM {{ ref('int_relatorio_unificado') }}
),

seed AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        emissor,
        classe_ativo,
        tipo_ativo,
        codigo_ativo,
        ativo,
        indexador,
        data_vencimento,
        vencimento_em_dias,
        fl_vencido,
        vlr_atualizado_brl,
        moeda_ativo,
        fonte_dado
    FROM {{ ref('int_investimentos_faltantes_unificados') }}
),


final AS (
    SELECT * FROM relatorio
    UNION ALL
    SELECT * FROM seed
)

SELECT
    *,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM final
ORDER BY mes_base, pessoa, instituicao, classe_ativo, tipo_ativo, ativo
