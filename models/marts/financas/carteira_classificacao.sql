{{
  config(
    enabled=false,
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

WITH
base AS (
    SELECT
        mes_base,
        pessoa,
        ativo,
        indexador,
        classe_ativo,
        tipo_ativo,
        instituicao,
        data_vencimento,
        camada,
        fl_mes_atual
    FROM {{ ref('int_carteira') }}

    UNION ALL

    SELECT
        mes_base,
        pessoa,
        ativo,
        indexador,
        classe_ativo,
        tipo_ativo,
        instituicao,
        data_vencimento,
        camada,
        fl_mes_atual
    FROM {{ ref('int_carteira_disponibilidades') }}
),

final AS (
    SELECT DISTINCT
        mes_base,
        pessoa,
        ativo,
        indexador,
        classe_ativo,
        tipo_ativo,
        instituicao,
        data_vencimento,
        camada
    FROM base
    WHERE fl_mes_atual IS TRUE
)

SELECT
    final.*
FROM final
ORDER BY pessoa, camada, classe_ativo, tipo_ativo, ativo
