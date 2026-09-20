{{
  config(
    tags = ['financas', 'staging'],
  )
}}

WITH
source AS (
    SELECT * FROM {{ source('google_finance_sheet', 'carteira_classificacao') }}
),

renamed AS (
    SELECT
        pessoa,
        instituicao,
        classe_ativo,
        codigo_ativo,
        ativo,
        NULLIF(TRIM(data_vencimento), '')::DATE AS data_vencimento,
        moeda_ativo,
        camada,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM source
)

SELECT * FROM renamed
