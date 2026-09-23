{{ config(
    tags=["politica"]
) }}

WITH
legislatura_corrente AS (
    SELECT MAX(legislatura) AS legislatura
    FROM {{ ref('votacoes_placar') }}
),

radar AS (
    SELECT
        sk_parlamentar,
        casa,
        radar_parlamentar_id_nk,
        qt_votos_legislatura,
        qt_votos_alinhados_legislatura,
        perc_governismo_legislatura
    FROM {{ ref('fct_radarcongresso_governismo_legislatura') }}
    WHERE legislatura = (SELECT legislatura FROM legislatura_corrente)
),

-- Recorte à janela do radar (2023 T1 a 2025 T4): compara método, não janela.
janela_radar AS (
    SELECT DISTINCT
        ano,
        trimestre
    FROM {{ ref('fct_radarcongresso_governismo_trimestre') }}
),

oficial_janela AS (
    SELECT
        t1.sk_parlamentar,
        COUNT(*)
            AS qt_votos,
        COUNT(*) FILTER (WHERE t1.fl_seguiu_governo = 1)
            AS qt_votos_alinhados
    FROM {{ ref('votos_parlamentares') }} AS t1
    INNER JOIN janela_radar AS t2
        ON t1.ano = t2.ano AND t1.trimestre = t2.trimestre
    WHERE t1.legislatura = (SELECT legislatura FROM legislatura_corrente)
        AND t1.fl_seguiu_governo IS NOT NULL
    GROUP BY t1.sk_parlamentar
),

oficial_completa AS (
    SELECT
        sk_parlamentar,
        ROUND(100.0 * COUNT(*) FILTER (WHERE fl_seguiu_governo = 1) / NULLIF(COUNT(*), 0), 2)
            AS perc_governismo
    FROM {{ ref('votos_parlamentares') }}
    WHERE legislatura = (SELECT legislatura FROM legislatura_corrente)
        AND fl_seguiu_governo IS NOT NULL
    GROUP BY sk_parlamentar
),

votos_por_partido AS (
    SELECT
        sk_parlamentar,
        sk_partido,
        partido_rotulo,
        COUNT(*) AS qt_votos
    FROM {{ ref('votos_parlamentares') }}
    WHERE sk_partido <> '{{ var("null_key") }}'
        AND legislatura = (SELECT legislatura FROM legislatura_corrente)
    GROUP BY sk_parlamentar, sk_partido, partido_rotulo
),

partido_predominante AS (
    SELECT DISTINCT ON (sk_parlamentar)
        sk_parlamentar,
        sk_partido,
        partido_rotulo
    FROM votos_por_partido
    ORDER BY sk_parlamentar ASC, qt_votos DESC, partido_rotulo ASC
),

comparado AS (
    SELECT
        t2.sk_parlamentar,
        t1.casa,
        t2.deputado_id_nk,
        t2.senador_id_nk,
        t2.nome,
        t2.uf,
        t5.sk_partido,
        t5.partido_rotulo
            AS partido_predominante,
        t1.radar_parlamentar_id_nk
            AS id_parlamentar_radar,
        t3.qt_votos
            AS qt_votos_oficial,
        t3.qt_votos_alinhados
            AS qt_votos_alinhados_oficial,
        t1.qt_votos_legislatura
            AS qt_votos_radar,
        t1.qt_votos_alinhados_legislatura
            AS qt_votos_alinhados_radar,
        t1.perc_governismo_legislatura
            AS perc_governismo_radar,
        t4.perc_governismo
            AS perc_governismo_oficial_legislatura_completa,
        ROUND(100.0 * t3.qt_votos_alinhados / NULLIF(t3.qt_votos, 0), 2)
            AS perc_governismo_oficial,
        t3.qt_votos - t1.qt_votos_legislatura
            AS diferenca_qt_votos,
        ROUND(100.0 * t3.qt_votos_alinhados / NULLIF(t3.qt_votos, 0), 2)
        - t1.perc_governismo_legislatura
            AS diferenca_pp
    FROM radar AS t1
    INNER JOIN {{ ref('dim_parlamentares') }} AS t2
        ON t1.sk_parlamentar = t2.sk_parlamentar
    LEFT JOIN oficial_janela AS t3
        ON t2.sk_parlamentar = t3.sk_parlamentar
    LEFT JOIN oficial_completa AS t4
        ON t2.sk_parlamentar = t4.sk_parlamentar
    LEFT JOIN partido_predominante AS t5
        ON t2.sk_parlamentar = t5.sk_parlamentar
),

final AS (
    SELECT
        t1.*,
        ABS(t1.diferenca_pp)
            AS diferenca_abs_pp,
        (ABS(t1.diferenca_pp) > 5)::INT
            AS fl_divergencia_relevante,
        CASE
            WHEN t1.perc_governismo_oficial IS NULL THEN 'SO RADAR'
            ELSE 'AMBAS'
        END
            AS fonte_disponivel,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM comparado AS t1
)

SELECT * FROM final
