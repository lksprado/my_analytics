{{
  config(
    materialized = 'table',
    tags = ['financas', 'intermediate'],
  )
}}

WITH

ativos_saldo_avenue   AS (
    SELECT
        period_start                       AS mes_base,
        pessoa,
        'AVENUE'                           AS instituicao,
        'NAO APLICAVEL'                    AS conglomerado_fgc,
        'DISPONIBILIDADE'                  AS classe_ativo,
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
        moeda_ativo
    FROM {{ ref('stg_assets') }}
    INNER JOIN {{ ref('stg_usd') }}
        ON period_end = data_referencia
    WHERE asset_class = 'CASH'
),

ativos_bradesco_lucas AS (
    SELECT
        mes_base,
        'BRADESCO'           AS instituicao,
        'BRADESCO'           AS conglomerado_fgc,
        'DISPONIBILIDADE'    AS classe_ativo,
        'BRDCONTALCS'        AS codigo_ativo,
        'SALDO EM CONTA'     AS ativo,
        saldo_bradesco_lucas AS vlr_atualizado_brl,
        'BRL'                AS moeda_ativo,
        'lucas'              AS pessoa
    FROM {{ ref('stg_patrimonio') }}
),

ativos_bradesco_deusa AS (
    SELECT
        mes_base,
        'BRADESCO'           AS instituicao,
        'BRADESCO'           AS conglomerado_fgc,
        'DISPONIBILIDADE'    AS classe_ativo,
        'BRDCONTADEU'        AS codigo_ativo,
        'SALDO EM CONTA'     AS ativo,
        saldo_bradesco_deusa AS vlr_atualizado_brl,
        'BRL'                AS moeda_ativo,
        'deusa'              AS pessoa
    FROM {{ ref('stg_patrimonio_deusa') }}
),

ativos_nubank_deusa AS (
    SELECT
        mes_base,
        'NUBANK'           AS instituicao,
        'NUBANK'           AS conglomerado_fgc,
        'DISPONIBILIDADE'  AS classe_ativo,
        'NUBCONTADEU'      AS codigo_ativo,
        'SALDO EM CONTA'   AS ativo,
        saldo_nubank_deusa AS vlr_atualizado_brl,
        'BRL'              AS moeda_ativo,
        'deusa'            AS pessoa
    FROM {{ ref('stg_patrimonio_deusa') }}
),

ativos_cashback_lucas AS (
    SELECT
        mes_base,
        'NUBANK'                    AS instituicao,
        'NUBANK'                    AS conglomerado_fgc,
        'DISPONIBILIDADE'           AS classe_ativo,
        'NUBCASHLCS'                AS codigo_ativo,
        'SALDO EM CONTA'            AS ativo,
        saldo_nubank_cashback_lucas AS vlr_atualizado_brl,
        'BRL'                       AS moeda_ativo,
        'lucas'                     AS pessoa
    FROM {{ ref('stg_patrimonio') }}
),

ativos_cashback_deusa AS (
    SELECT
        mes_base,
        'NUBANK'                    AS instituicao,
        'NUBANK'                    AS conglomerado_fgc,
        'DISPONIBILIDADE'           AS classe_ativo,
        'NUBCASHDEU'                AS codigo_ativo,
        'SALDO EM CONTA'            AS ativo,
        saldo_nubank_cashback_deusa AS vlr_atualizado_brl,
        'BRL'                       AS moeda_ativo,
        'deusa'                     AS pessoa
    FROM {{ ref('stg_patrimonio_deusa') }}
),

ativos_wise_lucas AS (
    SELECT
        mes_base,
        'WISE'            AS instituicao,
        'NAO APLICAVEL'   AS conglomerado_fgc,
        'DISPONIBILIDADE' AS classe_ativo,
        'WISCONTALCS'     AS codigo_ativo,
        'SALDO EM CONTA'  AS ativo,
        saldo_wise_lucas  AS vlr_atualizado_brl,
        'USD'             AS moeda_ativo,
        'lucas'           AS pessoa
    FROM {{ ref('stg_patrimonio') }}
),

ativos_bitcoin_lucas AS (
    SELECT
        mes_base,
        'AUTOCUSTODIA'      AS instituicao,
        'NAO APLICAVEL'     AS conglomerado_fgc,
        'DISPONIBILIDADE'   AS classe_ativo,
        'BTCCONTALCS'       AS codigo_ativo,
        'SALDO EM CONTA'    AS ativo,
        saldo_bitcoin_lucas AS vlr_atualizado_brl,
        'BTC'               AS moeda_ativo,
        'lucas'             AS pessoa
    FROM {{ ref('stg_patrimonio') }}
),

ativos_bb_jessica AS (
    SELECT
        mes_base,
        'BANCO DO BRASIL'          AS instituicao,
        'BANCO DO BRASIL'          AS conglomerado_fgc,
        'DISPONIBILIDADE'          AS classe_ativo,
        'BBCONTAJSS'               AS codigo_ativo,
        'SALDO EM CONTA'           AS ativo,
        saldo_banco_brasil_jessica AS vlr_atualizado_brl,
        'BRL'                      AS moeda_ativo,
        'jessica'                  AS pessoa
    FROM {{ ref('stg_patrimonio') }}
),

ativos_bb_deusa AS (
    SELECT
        mes_base,
        'BANCO DO BRASIL'        AS instituicao,
        'BANCO DO BRASIL'        AS conglomerado_fgc,
        'DISPONIBILIDADE'        AS classe_ativo,
        'BBCONTADEU'             AS codigo_ativo,
        'SALDO EM CONTA'         AS ativo,
        saldo_banco_brasil_deusa AS vlr_atualizado_brl,
        'BRL'                    AS moeda_ativo,
        'deusa'                  AS pessoa
    FROM {{ ref('stg_patrimonio_deusa') }}
),

unioned AS (
    SELECT * FROM ativos_bradesco_lucas
    UNION ALL
    SELECT * FROM ativos_bradesco_deusa
    UNION ALL
    SELECT * FROM ativos_nubank_deusa
    UNION ALL
    SELECT * FROM ativos_cashback_lucas
    UNION ALL
    SELECT * FROM ativos_cashback_deusa
    UNION ALL
    SELECT * FROM ativos_wise_lucas
    UNION ALL
    SELECT * FROM ativos_bitcoin_lucas
    UNION ALL
    SELECT * FROM ativos_bb_jessica
    UNION ALL
    SELECT * FROM ativos_bb_deusa
)

select * from unioned 