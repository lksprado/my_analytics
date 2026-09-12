{{
  config(
    materialized = 'table',
    tags = ['financas', 'staging'],
  )
}}

WITH
seed AS (
    SELECT
        dia,
        mes_num,
        ano_inicio,
        {{ clean_string("motivo", "upper") }} AS motivo
    FROM {{ ref('seed_datas_especiais') }}
)

SELECT * FROM seed
