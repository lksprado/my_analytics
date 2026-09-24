{{ config(
    tags=["politica"]
) }}

WITH
votos_orientados AS (
    SELECT
        t1.sk_parlamentar,
        t2.legislatura,
        t1.fl_seguiu_governo
    FROM {{ ref('fct_votos') }} AS t1
    INNER JOIN {{ ref('dim_calendario_legislativo') }} AS t2
        ON t1.sk_data = t2.data_sk
    WHERE
        t1.fl_seguiu_governo IS NOT NULL
        AND t1.sk_parlamentar <> '{{ var("null_key") }}'
),

final AS (
    SELECT
        sk_parlamentar,
        legislatura,
        SUM(fl_seguiu_governo)                                                        AS qt_votos_alinhados_governo,
        COUNT(*)                                                                      AS qt_votos_governismo,
        ROUND(100.0 * SUM(fl_seguiu_governo) / NULLIF(COUNT(*), 0), 0)::NUMERIC(3, 0) AS governismo_pct_modelo
    FROM votos_orientados
    GROUP BY sk_parlamentar, legislatura
)

SELECT
    *,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM final
