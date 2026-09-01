{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}

WITH
unioned AS (
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
        data_emissao,
        data_vencimento,
        moeda_ativo,
        vlr_atualizado_brl
    FROM {{ ref('stg_investimentos_faltantes_lucas') }}

    UNION ALL

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
        data_emissao,
        data_vencimento,
        moeda_ativo,
        vlr_atualizado_brl
    FROM {{ ref('stg_investimentos_faltantes_jessica') }}

    UNION ALL

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
        data_emissao,
        data_vencimento,
        moeda_ativo,
        vlr_atualizado_brl
    FROM {{ ref('stg_investimentos_faltantes_deusa') }}
),

final AS (
    SELECT
        mes_base,
        pessoa,
        {{ normaliza_instituicao('instituicao') }} AS instituicao,
        emissor,
        classe_ativo,
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
        vlr_atualizado_brl,
        moeda_ativo
    FROM unioned
)

SELECT * FROM final ORDER BY mes_base, pessoa
