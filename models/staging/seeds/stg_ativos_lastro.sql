{{
  config(
    tags = ['financas', 'staging'],
  )
}}

SELECT
    {{ clean_string("codigo_ativo", "upper") }}      AS codigo_ativo,
    {{ clean_string("veiculo", "upper") }}           AS veiculo,
    {{ clean_string("lastro", "upper") }}            AS lastro,
    {{ clean_string("classe_referencia", "upper") }} AS classe_referencia,
    '{{ run_started_at }}'::TIMESTAMPTZ             AS model_run_at
FROM {{ ref('seed_ativos_lastro') }}
