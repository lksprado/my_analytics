{{ config(
    tags=["politica"]
) }}

WITH scores AS (
    SELECT * FROM {{ ref('int_parlamentares_pontuacao_explodida') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['casa', 'congresso_id_fk']) }} AS sk_parlamentar,
    ano,
    pontuacao,
    nota_base_votacoes,
    nota_base_gastos,
    nota_base_presenca,
    nota_base_privilegios,
    bonus_processos,
    bonus_producao_legislativa,
    bonus_articulacao_legislativa,
    '{{ run_started_at }}'::TIMESTAMPTZ                                 AS model_run_at
FROM scores
