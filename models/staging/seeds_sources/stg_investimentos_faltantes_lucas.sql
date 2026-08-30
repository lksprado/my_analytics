{{
  config(
    materialized = 'table',
    tags = ['financas', 'staging'],
  )
}}

WITH
seed AS (
    SELECT * FROM {{ ref('investimentos_faltantes_lucas') }}
),

renamed AS (
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
        data_emissao,
        data_vencimento,
        vlr_atualizado_brl,
        moeda_ativo
    FROM seed
    ORDER BY mes_base, instituicao, ativo
)

SELECT * FROM renamed
