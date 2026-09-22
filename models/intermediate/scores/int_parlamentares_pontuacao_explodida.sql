{{ config(
    tags=["camara", "senado", "score"]
) }}

WITH base AS (
    SELECT * FROM {{ ref('int_parlamentares_pontuacao') }}
),

-- A origem entrega o histórico anual como texto com aspas simples, não JSON.
exploded AS (
    SELECT
        base.*,
        ranking_item
    FROM base
    CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS(
        REPLACE(base.composicao_pontuacao_anos, '''', '"')::JSONB
    ) AS ranking_item
)

SELECT
    casa,
    ranking_id_nk,
    congresso_id_fk,
    nome,
    nome_civil,
    partido,
    situacao,
    uf,
    slug,
    pontuacao_geral,
    ranking_geral,
    ranking_casa,
    ranking_partido,
    ranking_estado,
    ranking_casa_estado,
    (ranking_item ->> 'ano')::INT                                              AS ano,
    (ranking_item -> 'nota_base' ->> 'votacoes')::NUMERIC(18, 4)               AS nota_base_votacoes,
    (ranking_item -> 'nota_base' ->> 'gastos')::NUMERIC(18, 4)                 AS nota_base_gastos,
    (ranking_item -> 'nota_base' ->> 'presenca')::NUMERIC(18, 4)               AS nota_base_presenca,
    (ranking_item -> 'nota_base' ->> 'privilegios')::NUMERIC(18, 4)            AS nota_base_privilegios,
    (ranking_item -> 'bonus_penalidades' ->> 'processos')::NUMERIC(18, 4)      AS bonus_processos,
    (ranking_item -> 'bonus_penalidades' ->> 'producao_legislativa')::NUMERIC(18, 4)
        AS bonus_producao_legislativa,
    (ranking_item -> 'bonus_penalidades' ->> 'articulacao_legislativa')::NUMERIC(18, 4)
        AS bonus_articulacao_legislativa,
    (ranking_item ->> 'pontuacao')::NUMERIC(18, 4)                             AS pontuacao,
    '{{ run_started_at }}'::TIMESTAMPTZ                                        AS model_run_at
FROM exploded
