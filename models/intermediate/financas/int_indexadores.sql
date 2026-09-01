{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}

WITH
indexadores AS (
    SELECT
        mes_base,
        minha_inflacao,
        ipca,
        igpm,
        selic,
        cdi,
        minha_inflacao_acum,
        ipca_acum,
        igpm_acum,
        selic_acum,
        cdi_acum
    FROM {{ ref('stg_patrimonio') }}
)
SELECT * FROM indexadores
