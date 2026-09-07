{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}

WITH
avenue AS (
    SELECT
        period_start                                         AS mes_base,
        pessoa,
        'AVENUE'                                             AS instituicao,
        'ACAO'                                               AS tipo_ativo,
        symbol_cusip                                         AS codigo_ativo,
        (market_value::INT * vlr_usd)::INT                   AS vlr_atualizado_brl,
        moeda_ativo,
        'AVENUE'                                             AS fonte_dado
    FROM {{ ref('stg_assets') }}
    INNER JOIN {{ ref('stg_usd') }}
        ON period_end = data_referencia
    WHERE asset_class = 'EQUITIES'
),

acoes AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        'ACAO' AS tipo_ativo,
        codigo_ativo,
        vlr_atualizado_brl,
        moeda_ativo,
        'B3'   AS fonte_dado
    FROM {{ ref('stg_acoes') }}
),

bdr AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        'ACAO' AS tipo_ativo,
        codigo_ativo,
        vlr_atualizado_brl,
        moeda_ativo,
        'B3'   AS fonte_dado
    FROM {{ ref('stg_bdr') }}
),

etf AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        'FUNDO' AS tipo_ativo,
        codigo_ativo,
        vlr_atualizado_brl,
        moeda_ativo,
        'B3'    AS fonte_dado
    FROM {{ ref('stg_etf') }}
),

fundos AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        'FUNDO' AS tipo_ativo,
        codigo_ativo,
        vlr_atualizado_brl,
        moeda_ativo,
        'B3'    AS fonte_dado
    FROM {{ ref('stg_fundos') }}
),

unioned AS (
    SELECT * FROM avenue
    UNION ALL
    SELECT * FROM acoes
    UNION ALL
    SELECT * FROM etf
    UNION ALL
    SELECT * FROM fundos
    UNION ALL
    SELECT * FROM bdr
),

final AS (
    SELECT
        mes_base,
        pessoa,
        {{ normaliza_instituicao('instituicao') }} AS instituicao,
        'RENDA VARIAVEL'                           AS classe_ativo,
        tipo_ativo,
        codigo_ativo,
        codigo_ativo                               AS ativo,
        SUM(vlr_atualizado_brl)::INT               AS vlr_atualizado_brl,
        moeda_ativo,
        fonte_dado
    FROM unioned
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 9, 10
)

SELECT * FROM final
ORDER BY mes_base, pessoa, instituicao, tipo_ativo
