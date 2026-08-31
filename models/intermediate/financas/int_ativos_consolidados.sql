{{
  config(
    materialized = 'table',
    tags = ['financas', 'intermediate'],
  )
}}

WITH
unioned AS (
  SELECT 
    mes_base,
    pessoa,
    instituicao,
    NULL::TEXT AS emissor,
    conglomerado_fgc,
    classe_ativo,
    codigo_ativo,
    ativo,
    NULL::TEXT AS indexador,
    vlr_atualizado_brl,
    NULL::DATE AS data_vencimento,
    NULL::INT AS vencimento_em_dias,
    NULL::BOOLEAN AS fl_vencido,
    moeda_ativo
  FROM {{ ref('int_disponibilidades_isoladas')}}
  UNION ALL
  SELECT
    mes_base,
    pessoa,
    instituicao,
    emissor,
    conglomerado_fgc,
    classe_ativo,
    codigo_ativo,
    ativo,
    indexador,
    vlr_atualizado_brl,
    data_vencimento,
    vencimento_em_dias,
    fl_vencido,
    moeda_ativo
  FROM {{ ref('int_renda_unificada')}}
)

select * from unioned