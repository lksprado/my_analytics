{{ config(
    tags=["politica"]
) }}

WITH
comparativo AS (
    SELECT * FROM {{ ref('comparativo_governismo_legislatura') }}
    WHERE partido_predominante IS NOT NULL
),

final AS (
    SELECT
        casa,
        sk_partido,
        partido_predominante
            AS partido,
        COUNT(*)
            AS qt_parlamentares,
        COUNT(*) FILTER (WHERE fonte_disponivel = 'AMBAS')
            AS qt_parlamentares_ambas_fontes,
        ROUND(AVG(perc_governismo_oficial), 2)
            AS perc_governismo_oficial_medio,
        ROUND(AVG(perc_governismo_radar), 2)
            AS perc_governismo_radar_medio,
        ROUND(AVG(diferenca_pp), 2)
            AS diferenca_pp_media,
        ROUND(AVG(diferenca_abs_pp), 2)
            AS erro_absoluto_medio,
        COUNT(*) FILTER (WHERE fl_divergencia_relevante = 1)
            AS qt_divergencias_acima_5pp,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM comparativo
    GROUP BY casa, sk_partido, partido_predominante
)

SELECT * FROM final
