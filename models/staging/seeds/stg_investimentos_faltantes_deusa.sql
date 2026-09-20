{{
  config(
    tags = ['financas', 'staging'],
  )
}}

WITH
seed AS (
    SELECT * FROM {{ ref('seed_investimentos_faltantes_deusa') }}
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
        moeda_ativo,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM seed
    ORDER BY mes_base, pessoa, instituicao, ativo
)

SELECT * FROM renamed
