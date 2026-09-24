{{ config(
    tags=["politica"]
) }}

WITH
avaliados AS (
    SELECT *
    FROM {{ ref('score_vs_governismo') }}
    WHERE pontuacao IS NOT NULL
        AND sk_partido IS NOT NULL
),

final AS (
    SELECT
        casa,
        sk_partido,
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
        ROUND(
            100.0 * SUM(qt_votos_alinhados_governo)::NUMERIC
            / NULLIF(SUM(qt_votos_governismo), 0), 2
        )
            AS governismo_pct_modelo,
        ROUND(
            SUM(disciplina_pct * qt_votos_disciplina)
            / NULLIF(SUM(qt_votos_disciplina), 0), 2
        )
            AS disciplina_pct,
        MIN(fl_componentes_normalizados)
            AS fl_componentes_normalizados,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM avaliados
    GROUP BY casa, sk_partido, partido_predominante, ano
)

SELECT * FROM final
