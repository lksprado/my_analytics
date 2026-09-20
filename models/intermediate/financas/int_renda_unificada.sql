{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}

WITH
variavel AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        NULL::TEXT    AS emissor,
        NULL::TEXT    AS conglomerado_fgc,
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
    FROM {{ ref('int_renda_variavel') }}
),

fixa AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        emissor,
        conglomerado_fgc,
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
    FROM {{ ref('int_renda_fixa') }}
),

unioned AS (
    SELECT * FROM variavel
    UNION ALL
    SELECT * FROM fixa
)

SELECT
    *,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM unioned
ORDER BY mes_base, pessoa, instituicao, classe_ativo, tipo_ativo, ativo
