{{
  config(
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

WITH
listados AS (
  SELECT DISTINCT
        pessoa,
        instituicao,
        classe_ativo,
        codigo_ativo,
        ativo,
        data_vencimento,
        moeda_ativo
  FROM {{ ref('int_ativos_consolidados')}}
  where mes_base >= '2026-06-01'
)
classificados AS (
  SELECT DISTINCT
        pessoa,
        instituicao,
        classe_ativo,
        codigo_ativo,
        ativo,
        data_vencimento,
        moeda_ativo
  FROM {{ ref('stg_carteira_classificacao')}}
)
faltam_classificar_sheets AS (
    SELECT DISTINCT
        pessoa,
        instituicao,
        classe_ativo,
        codigo_ativo,
        ativo,
        data_vencimento,
        moeda_ativo
    FROM listados
    LEFT ANTI JOIN
        ON listados.codigo_ativo = classificacao.codigo_ativo
    
)
SELECT * FROM faltam_classificar_sheets