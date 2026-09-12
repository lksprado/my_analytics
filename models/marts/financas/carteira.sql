{{
  config(
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

{#- Camada é estado atual, não SCD2: a planilha perdeu mes_base, então um mês
    passado carrega a classificação de hoje.

    A chave do join inclui instituicao: BRSTNCLTN806 da Deusa está no Banco do
    Brasil e no Nubank, e sem ela a posição duplica.

    fonte_dado vem do CTE-folha de cada ramo do intermediate, porque depois do
    UNION ALL a origem não é recuperável. -#}

WITH
datas AS (
    SELECT DISTINCT
        month_start_date,
        month_end_date,
        quarter_of_year,
        year_number
    FROM {{ ref('dim_datas') }}
),

posicoes AS (
    SELECT * FROM {{ ref('int_ativos_consolidados') }}
),

classificacao AS (
    SELECT
        pessoa,
        codigo_ativo,
        instituicao,
        camada
    FROM {{ ref('stg_carteira_classificacao') }}
),

final AS (
    SELECT
        t1.mes_base,
        t2.month_end_date  AS mes_final,
        t2.quarter_of_year AS trimestre,
        t2.year_number     AS ano,
        t1.pessoa,
        t1.instituicao,
        t1.emissor,
        t1.conglomerado_fgc,
        t1.classe_ativo,
        t1.tipo_ativo,
        t1.codigo_ativo,
        COALESCE(t3.camada, 'NAO CLASSIFICADO') AS camada,
        t1.ativo,
        t1.indexador,
        t1.data_vencimento,
        t1.vencimento_em_dias,
        t1.fl_vencido,
        t1.vlr_atualizado_brl,
        t1.moeda_ativo,
        t1.fonte_dado,
        t1.mes_base = MAX(t1.mes_base) OVER () AS fl_mes_atual
    FROM posicoes AS t1
    INNER JOIN datas AS t2
        ON t1.mes_base = t2.month_start_date
    LEFT JOIN classificacao AS t3
        ON t1.pessoa = t3.pessoa
        AND t1.codigo_ativo = t3.codigo_ativo
        AND t1.instituicao = t3.instituicao
)

SELECT
    final.*,
    CURRENT_TIMESTAMP AS model_updated_at
FROM final
ORDER BY mes_base, pessoa, instituicao, classe_ativo, tipo_ativo, ativo
