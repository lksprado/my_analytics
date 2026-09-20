{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}

WITH
lucas AS (
    SELECT * FROM {{ ref('stg_luc_contas') }}
),

jessica AS (
    SELECT * FROM {{ ref('stg_jsc_contas') }}
),

unioned AS (
    SELECT * FROM lucas
    UNION ALL
    SELECT * FROM jessica
),

final AS (
    SELECT
        mes_fatura,
        mes_debito,
        pessoa,
        data_debito,
        nome_dia,
        dia_ajustado,
        dia_real,
        mercado,
        diversos,
        assinaturas,
        role,
        transporte,
        apartamento,
        saude,
        educacao,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM unioned
)

SELECT * FROM final
ORDER BY mes_debito, pessoa
