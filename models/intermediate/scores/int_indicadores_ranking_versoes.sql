{{ config(
    tags=["politica"]
) }}

WITH
versoes AS (
    SELECT
        *,
        'CAMARA' AS casa
    FROM {{ ref('snap_ranking_politicos_deputados') }}
    UNION ALL
    SELECT
        *,
        'SENADO' AS casa
    FROM {{ ref('snap_ranking_politicos_senadores') }}
),

limpas AS (
    SELECT
        casa,
        id                                                               AS parlamentar_fonte_id_nk,
        REGEXP_REPLACE(SPLIT_PART(url_foto, '/', 7), '\D', '', 'g')::INT AS parlamentar_casa_id,
        composicao_pontuacao_pontuacao::NUMERIC                          AS pontuacao_geral,
        composicao_pontuacao_ranking_geral::NUMERIC                      AS ranking_geral,
        composicao_pontuacao_ranking_casa::NUMERIC                       AS ranking_casa,
        composicao_pontuacao_ranking_partido::NUMERIC                    AS ranking_partido,
        composicao_pontuacao_ranking_estado::NUMERIC                     AS ranking_estado,
        composicao_pontuacao_ranking_casa_estado::NUMERIC                AS ranking_casa_estado,
        composicao_pontuacao_anos,
        dbt_valid_from::DATE                                             AS data_coleta,
        dbt_valid_to::DATE                                               AS data_fim_vigencia
    FROM versoes
    WHERE COALESCE(dbt_is_deleted, 'False') <> 'True'
),

atuais AS (
    SELECT
        l.casa,
        l.parlamentar_fonte_id_nk,
        l.parlamentar_casa_id,
        i.indicador,
        'ATUAL'    AS periodo_tipo,
        NULL::DATE AS periodo_inicio,
        NULL::DATE AS periodo_fim,
        i.valor    AS valor_original,
        l.data_coleta,
        l.data_fim_vigencia
    FROM limpas AS l
    CROSS JOIN LATERAL (
        VALUES
            ('PONTUACAO GERAL', l.pontuacao_geral),
            ('POSICAO GERAL', l.ranking_geral),
            ('POSICAO NA CASA', l.ranking_casa),
            ('POSICAO NO PARTIDO', l.ranking_partido),
            ('POSICAO NA UF', l.ranking_estado),
            ('POSICAO NA CASA E UF', l.ranking_casa_estado)
    ) AS i (indicador, valor)
    WHERE i.valor IS NOT NULL
),

-- A origem entrega o histórico anual como texto com aspas simples, não JSON.
anos AS (
    SELECT
        l.casa,
        l.parlamentar_fonte_id_nk,
        l.parlamentar_casa_id,
        l.data_coleta,
        l.data_fim_vigencia,
        item
    FROM limpas AS l
    CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS(REPLACE(l.composicao_pontuacao_anos, '''', '"')::JSONB) AS item
),

anuais AS (
    SELECT
        a.casa,
        a.parlamentar_fonte_id_nk,
        a.parlamentar_casa_id,
        i.indicador,
        'ANO'                                      AS periodo_tipo,
        MAKE_DATE((a.item ->> 'ano')::INT, 1, 1)   AS periodo_inicio,
        MAKE_DATE((a.item ->> 'ano')::INT, 12, 31) AS periodo_fim,
        i.valor                                    AS valor_original,
        a.data_coleta,
        a.data_fim_vigencia
    FROM anos AS a
    CROSS JOIN LATERAL (
        VALUES
            ('PONTUACAO ANUAL', (a.item ->> 'pontuacao')::NUMERIC),
            ('NOTA VOTACOES', (a.item -> 'nota_base' ->> 'votacoes')::NUMERIC),
            ('NOTA GASTOS', (a.item -> 'nota_base' ->> 'gastos')::NUMERIC),
            ('NOTA PRESENCA', (a.item -> 'nota_base' ->> 'presenca')::NUMERIC),
            ('NOTA PRIVILEGIOS', (a.item -> 'nota_base' ->> 'privilegios')::NUMERIC),
            ('BONUS PROCESSOS', (a.item -> 'bonus_penalidades' ->> 'processos')::NUMERIC),
            ('BONUS PRODUCAO LEGISLATIVA', (a.item -> 'bonus_penalidades' ->> 'producao_legislativa')::NUMERIC),
            ('BONUS ARTICULACAO LEGISLATIVA', (a.item -> 'bonus_penalidades' ->> 'articulacao_legislativa')::NUMERIC)
    ) AS i (indicador, valor)
    WHERE (a.item ->> 'ano') IS NOT NULL
        AND i.valor IS NOT NULL
),

final AS (
    SELECT
        'RANKING DOS POLITICOS'             AS fonte,
        casa,
        parlamentar_fonte_id_nk,
        indicador,
        periodo_tipo,
        periodo_inicio,
        periodo_fim,
        valor_original,
        NULL::INT                           AS qt_base,
        data_coleta,
        data_fim_vigencia,
        parlamentar_casa_id,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM atuais
    UNION ALL
    SELECT
        'RANKING DOS POLITICOS'             AS fonte,
        casa,
        parlamentar_fonte_id_nk,
        indicador,
        periodo_tipo,
        periodo_inicio,
        periodo_fim,
        valor_original,
        NULL::INT                           AS qt_base,
        data_coleta,
        data_fim_vigencia,
        parlamentar_casa_id,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM anuais
)

SELECT * FROM final
