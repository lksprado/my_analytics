{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}

WITH
avenue AS (
    SELECT
        period_start           AS mes_base,
        pessoa,
        'AVENUE'               AS instituicao,
        CASE
            WHEN symbol_cusip = 'US TREASURY'
                THEN 'US TREASURY'
            ELSE 'NAO APLICAVEL'
        END                    AS emissor,
        'TITULO PUBLICO'       AS tipo_ativo,
        symbol_cusip           AS codigo_ativo,
        description            AS ativo,
        NULL::TEXT             AS indexador,
        NULL::DATE             AS data_emissao,
        NULL::DATE             AS data_vencimento,
        market_value * vlr_usd AS vlr_atualizado_brl,
        moeda_ativo
    FROM {{ ref('stg_assets') }}
    INNER JOIN {{ ref('stg_usd') }}
        ON period_end = data_referencia
    WHERE asset_class = 'FIXED INCOME'
),

b3 AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        TRIM(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        emissor,
                        '\s+S(?:\.|/)?A\.?\s*$',
                        '',
                        'i'
                    ),
                    '[[:punct:]]+',
                    ' ',
                    'g'
                ),
                '\s+',
                ' ',
                'g'
            )
        ) AS emissor,                   
        'TITULO PRIVADO'                                                                                                        AS tipo_ativo,
        codigo                                                                                                                  AS codigo_ativo,
        TRIM(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        produto,
                        '\s+S(?:\.|/)?A\.?\s*$',
                        '',
                        'i'
                    ),
                    '[[:punct:]]+',
                    ' ',
                    'g'
                ),
                '\s+',
                ' ',
                'g'
            )
        ) || ' - ' || EXTRACT(YEAR FROM data_vencimento) AS ativo,
        indexador,
        data_emissao,
        data_vencimento,
        COALESCE(vlr_atualizado_curva, vlr_atualizado_mtm)                                                                      AS vlr_atualizado_brl,
        moeda_ativo
    FROM {{ ref('stg_renda_fixa') }}
),

b3_td AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        'TESOURO NACIONAL'               AS emissor,
        'TITULO PUBLICO'                 AS tipo_ativo,
        codigo_isin                      AS codigo_ativo,
        TRIM(produto)                    AS ativo,
        indexador,
        NULL::DATE                       AS data_emissao,
        data_vencimento,
        vlr_atualizado_brl,
        moeda_ativo
    FROM {{ ref('stg_tesouro_direto') }}
),
unioned AS (
    SELECT * FROM avenue
    UNION ALL
    SELECT * FROM b3
    UNION ALL
    SELECT * FROM b3_td
),

final AS (
    SELECT
        mes_base,
        pessoa,
        {{ normaliza_instituicao('instituicao') }} AS instituicao,
        CASE
            WHEN emissor LIKE '%BANCO MAXIMA%' THEN 'BANCO MASTER'
            WHEN emissor LIKE '%BANCO MASTER%' THEN 'BANCO MASTER'
            WHEN emissor LIKE '%NU FINANCEIRA%' THEN 'NUBANK'
            ELSE emissor
        END AS emissor,
        'RENDA FIXA'             AS classe_ativo,
        tipo_ativo,
        codigo_ativo,
        ativo,
        indexador,
        data_emissao,
        data_vencimento,
        CASE
            WHEN data_vencimento >= CURRENT_DATE
                THEN data_vencimento - CURRENT_DATE
        END                      AS vencimento_em_dias,
        (
            data_vencimento IS NOT NULL
            AND data_vencimento < CURRENT_DATE
        )                        AS fl_vencido,
        {#- Dinheiro no warehouse trafega em reais inteiros: int_renda_variavel,
            int_renda_fixa_loop, int_disponibilidades_isoladas e int_dividendos
            já entregam ::INT, e patrimonio vem inteiro do staging. Este era o
            único ramo que deixava numeric passar (market_value * vlr_usd da
            Avenue e o COALESCE curva/MTM da B3), e bastava ele para contaminar
            int_renda_fixa -> int_renda_unificada -> int_ativos_consolidados ->
            marts.carteira e todos os seus recortes.

            O cast fica aqui, no CTE onde os três ramos convergem, e não em cada
            um deles. ::INT arredonda (não trunca), que é o que se quer. -#}
        vlr_atualizado_brl::INT AS vlr_atualizado_brl,
        moeda_ativo
    FROM unioned
    WHERE vlr_atualizado_brl IS NOT NULL
)
SELECT * FROM final ORDER BY mes_base, pessoa
