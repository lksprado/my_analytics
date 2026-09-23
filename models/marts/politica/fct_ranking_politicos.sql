{{ config(
    tags=["politica"]
) }}

WITH scores AS (
    SELECT * FROM {{ ref('int_parlamentares_pontuacao') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['casa', 'congresso_id_fk']) }} AS sk_parlamentar,
    pontuacao_geral,
    ranking_geral,
    ranking_casa,
    ranking_partido,
    ranking_estado,
    ranking_casa_estado,
    '{{ run_started_at }}'::TIMESTAMPTZ                                 AS model_run_at
FROM scores
WHERE pontuacao_geral IS NOT NULL
