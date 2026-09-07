{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}

WITH
unioned AS (
    SELECT * FROM {{ ref('int_renda_fixa_incompleta') }}
    UNION ALL
    SELECT * FROM {{ ref('int_renda_fixa_loop') }}
),
final AS (
    SELECT
        t1.mes_base,
        t1.pessoa,
        t1.instituicao,
        t1.emissor,
        CASE 
            WHEN t2.conglomerado IS NULL AND t1.emissor = 'TESOURO NACIONAL'
                THEN 'TESOURO NACIONAL'
            WHEN t2.conglomerado IS NOT NULL
                THEN t2.conglomerado
            ELSE 'NAO APLICAVEL'
        END AS conglomerado_fgc,
        t1.classe_ativo,
        t1.tipo_ativo,
        t1.codigo_ativo,
        t1.ativo,
        t1.indexador,
        t1.data_emissao,
        t1.data_vencimento,
        t1.vencimento_em_dias,
        t1.fl_vencido,
        t1.vlr_atualizado_brl,
        t1.moeda_ativo,
        t1.fonte_dado
    FROM unioned AS t1
    LEFT JOIN {{ ref('stg_de_para_instituicoes_fgc') }} AS t2
    ON t1.emissor = t2.instituicao
)

SELECT * FROM final ORDER BY mes_base, pessoa
