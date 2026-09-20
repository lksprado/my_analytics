{{
  config(
    tags = ['financas', 'staging'],
  )
}}

WITH
seed AS (
    SELECT
        dia,
        mes_num,
        ano_inicio,
        {{ clean_string("motivo", "upper") }} AS motivo,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM {{ ref('seed_datas_especiais') }}
)

SELECT * FROM seed
