{{ config(
    tags=["politica"]
) }}

WITH
legislatura_corrente AS (
    SELECT MAX(legislatura) AS legislatura
    FROM {{ ref('votacoes') }}
),

-- Trimestre sem percentual no radar também não tem voto nosso: a linha não informa nada.
radar AS (
    SELECT
        sk_parlamentar,
        casa,
        radar_parlamentar_id_nk,
        ano,
        trimestre,
        data_trimestre,
        governismo_pct_radar
    FROM {{ ref('fct_radarcongresso_governismo_trimestre') }}
),

modelo AS (
    SELECT
        sk_parlamentar,
        ano,
        trimestre,
        COUNT(*)
            AS qt_votos,
        ROUND(100.0 * COUNT(*) FILTER (WHERE fl_seguiu_governo = 1) / NULLIF(COUNT(*), 0), 2)
            AS governismo_pct
    FROM {{ ref('votos_parlamentares') }}
    WHERE legislatura = (SELECT legislatura FROM legislatura_corrente)
        AND fl_seguiu_governo IS NOT NULL
    GROUP BY sk_parlamentar, ano, trimestre
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
        t2.uf_mandato_recente AS uf,
        t4.sk_partido,
        t4.partido_rotulo
            AS partido_predominante,
        t1.radar_parlamentar_id_nk
            AS id_parlamentar_radar,
        t1.ano,
        t1.trimestre,
        t1.data_trimestre,
        t3.qt_votos
            AS qt_votos_modelo,
        t3.governismo_pct
            AS governismo_pct_modelo,
        t1.governismo_pct_radar,
        t3.governismo_pct - t1.governismo_pct_radar
            AS diferenca_pp
    FROM radar AS t1
    INNER JOIN {{ ref('dim_parlamentares') }} AS t2
        ON t1.sk_parlamentar = t2.sk_parlamentar
    LEFT JOIN modelo AS t3
        ON t2.sk_parlamentar = t3.sk_parlamentar
        AND t1.ano = t3.ano
        AND t1.trimestre = t3.trimestre
    LEFT JOIN partido_predominante AS t4
        ON t2.sk_parlamentar = t4.sk_parlamentar
),

final AS (
    SELECT
        t1.*,
        ABS(t1.diferenca_pp)
            AS diferenca_abs_pp,
        CASE
            WHEN t1.governismo_pct_modelo IS NULL THEN 'SO RADAR'
            ELSE 'AMBAS'
        END
            AS fonte_disponivel,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM comparado AS t1
)

SELECT * FROM final
