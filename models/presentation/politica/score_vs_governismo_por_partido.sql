{{ config(
    tags=["politica"]
) }}

WITH
-- Só os qualificados: sem percentil, o governismo não tem base.
qualificados AS (
    SELECT *
    FROM {{ ref('score_vs_governismo') }}
    WHERE quadrante IS NOT NULL
        AND partido_predominante IS NOT NULL
),

final AS (
    SELECT
        casa,
        partido_predominante
            AS partido,
        ano,
        COUNT(*)
            AS qt_parlamentares,
        ROUND(AVG(pontuacao), 4)
            AS pontuacao_media,
        ROUND(AVG(nota_base_votacoes), 4)
            AS nota_base_votacoes_media,
        ROUND(AVG(nota_base_gastos), 4)
            AS nota_base_gastos_media,
        ROUND(AVG(nota_base_presenca), 4)
            AS nota_base_presenca_media,
        ROUND(AVG(perc_governismo), 2)
            AS perc_governismo_medio,
        ROUND(
            100.0 * SUM(qt_votos_alinhados_governo)::NUMERIC
            / NULLIF(SUM(qt_votos_governismo), 0), 2
        )
            AS perc_governismo_ponderado,
        ROUND(
            SUM(perc_disciplina * qt_votos_disciplina)
            / NULLIF(SUM(qt_votos_disciplina), 0), 2
        )
            AS perc_disciplina_ponderado,
        BOOL_AND(flag_componentes_normalizados)
            AS flag_componentes_normalizados,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM qualificados
    GROUP BY casa, partido_predominante, ano
)

SELECT * FROM final
