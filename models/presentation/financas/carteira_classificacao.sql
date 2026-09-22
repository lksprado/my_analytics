{{
  config(
    tags = ['financas', 'marts'],
  )
}}

{#- Colado de volta na aba "classificacao": colunas e ordem têm de ser
    exatamente as de stg_carteira_classificacao. -#}

WITH
final AS (
    SELECT DISTINCT
        pessoa,
        instituicao,
        classe_ativo,
        codigo_ativo,
        ativo,
        data_vencimento,
        moeda_ativo,
        camada
    FROM {{ ref('carteira') }}
    WHERE fl_mes_atual IS TRUE
)

SELECT
    final.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM final
ORDER BY pessoa, camada, classe_ativo, instituicao, ativo
