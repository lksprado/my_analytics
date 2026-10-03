{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}

WITH
renda_variavel AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        NULL::TEXT    AS emissor,
        classe_ativo,
        tipo_ativo,
        codigo_ativo,
        ativo,
        NULL::TEXT    AS indexador,
        NULL::DATE    AS data_vencimento,
        NULL::INT     AS vencimento_em_dias,
        NULL::BOOLEAN AS fl_vencido,
        vlr_atualizado_brl,
        moeda_ativo,
        fonte_dado
    FROM {{ ref('int_relatorio_renda_variavel') }}
),

renda_fixa AS (
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
        data_vencimento,
        vencimento_em_dias,
        fl_vencido,
        vlr_atualizado_brl,
        moeda_ativo,
        fonte_dado
    FROM {{ ref('int_relatorio_renda_fixa') }}
),

disponibilidades AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        NULL::TEXT      AS emissor,
        classe_ativo,
        tipo_ativo,
        codigo_ativo,
        ativo,
        NULL::TEXT      AS indexador,
        NULL::DATE      AS data_vencimento,
        NULL::INT       AS vencimento_em_dias,
        NULL::BOOLEAN   AS fl_vencido,
        vlr_atualizado_brl,
        moeda_ativo,
        fonte_dado
    FROM {{ ref('int_relatorio_disponibilidades') }}
),

unioned AS (
    SELECT * FROM renda_variavel
    UNION ALL
    SELECT * FROM renda_fixa
    UNION ALL
    SELECT * FROM disponibilidades
)

SELECT
    *,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM unioned
ORDER BY mes_base, pessoa, instituicao, classe_ativo, tipo_ativo, ativo
