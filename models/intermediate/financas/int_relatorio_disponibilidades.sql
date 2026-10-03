{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}

WITH
avenue AS (
    SELECT
        period_start                       AS mes_base,
        pessoa,
        'AVENUE'                           AS instituicao,
        'DISPONIBILIDADE'                  AS classe_ativo,
        'CONTA CORRENTE'                   AS tipo_ativo,
        CASE
            WHEN pessoa = 'lucas'
                THEN 'AVECONTALCS'
            WHEN pessoa = 'jessica'
                THEN 'AVECONTAJSS'
            WHEN pessoa = 'deusa'
                THEN 'AVECONTADEU'
        END                                AS codigo_ativo,
        'SALDO EM CONTA'                   AS ativo,
        (market_value::INT * vlr_usd)::INT AS vlr_atualizado_brl,
        moeda_ativo,
        'RELATORIO AVENUE'                 AS fonte_dado
    FROM {{ ref('stg_assets') }}
    INNER JOIN {{ ref('stg_usd') }}
        ON period_end = data_referencia
    WHERE asset_class = 'CASH'
)

SELECT
    *,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM avenue
ORDER BY mes_base, pessoa
