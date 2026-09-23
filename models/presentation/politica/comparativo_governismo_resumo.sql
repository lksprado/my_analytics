{{ config(
    tags=["politica"]
) }}

WITH
comparativo AS (
    SELECT * FROM {{ ref('comparativo_governismo_trimestre') }}
),

final AS (
    SELECT
        casa,
        ano,
        trimestre,
        COUNT(*)
            AS qt_parlamentares,
        COUNT(*) FILTER (WHERE fonte_disponivel = 'AMBAS')
            AS qt_parlamentares_ambas_fontes,
        ROUND(AVG(perc_governismo_oficial), 2)
            AS perc_governismo_oficial_medio,
        ROUND(AVG(perc_governismo_radar), 2)
            AS perc_governismo_radar_medio,
        ROUND(CORR(perc_governismo_oficial, perc_governismo_radar)::NUMERIC, 4)
            AS correlacao,
        ROUND(AVG(diferenca_abs_pp), 2)
            AS erro_absoluto_medio,
        ROUND(AVG(diferenca_pp), 2)
            AS vies_medio,
        COUNT(*) FILTER (WHERE diferenca_abs_pp > 5)
            AS qt_divergencias_acima_5pp,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM comparativo
    GROUP BY casa, ano, trimestre
)

SELECT * FROM final
