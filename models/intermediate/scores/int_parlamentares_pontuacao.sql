{{ config(
    tags=["camara", "senado", "score"]
) }}

WITH
deputados AS (
    SELECT
        *,
        'CAMARA' AS casa
    FROM {{ ref('stg_ranking_deputados') }}
),

senadores AS (
    SELECT
        *,
        'SENADO' AS casa
    FROM {{ ref('stg_ranking_senadores') }}
),

unioned AS (
    SELECT
        casa,
        ranking_id_nk,
        congresso_id_fk,
        nome,
        nome_civil,
        partido,
        situacao,
        slug,
        uf,
        composicao_pontuacao_anos,
        composicao_pontuacao_pontuacao           AS pontuacao_geral,
        composicao_pontuacao_ranking_geral       AS ranking_geral,
        composicao_pontuacao_ranking_casa        AS ranking_casa,
        composicao_pontuacao_ranking_partido     AS ranking_partido,
        composicao_pontuacao_ranking_estado      AS ranking_estado,
        composicao_pontuacao_ranking_casa_estado AS ranking_casa_estado
    FROM deputados
    UNION ALL
    SELECT
        casa,
        ranking_id_nk,
        congresso_id_fk,
        nome,
        nome_civil,
        partido,
        situacao,
        slug,
        uf,
        composicao_pontuacao_anos,
        composicao_pontuacao_pontuacao,
        composicao_pontuacao_ranking_geral,
        composicao_pontuacao_ranking_casa,
        composicao_pontuacao_ranking_partido,
        composicao_pontuacao_ranking_estado,
        composicao_pontuacao_ranking_casa_estado
    FROM senadores
)

SELECT
    casa,
    ranking_id_nk,
    congresso_id_fk,
    nome,
    nome_civil,
    partido,
    situacao,
    slug,
    {{ uf_sigla('uf', 4) }}             AS uf,
    composicao_pontuacao_anos,
    pontuacao_geral,
    ranking_geral,
    ranking_casa,
    ranking_partido,
    ranking_estado,
    ranking_casa_estado,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM unioned
