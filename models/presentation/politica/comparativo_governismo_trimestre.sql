{{ config(
    tags=["politica"]
) }}

WITH
legislatura_corrente AS (
    SELECT MAX(legislatura) AS legislatura
    FROM {{ ref('votacoes_placar') }}
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
        perc_governismo_trimestre
    FROM {{ ref('fct_radarcongresso_governismo_trimestre') }}
),

oficial AS (
    SELECT
        sk_parlamentar,
        ano,
        trimestre,
        COUNT(*)
            AS qt_votos,
        ROUND(100.0 * COUNT(*) FILTER (WHERE voto_alinhado = 1) / NULLIF(COUNT(*), 0), 2)
            AS perc_governismo
    FROM {{ ref('governismo') }}
    WHERE legislatura = (SELECT legislatura FROM legislatura_corrente)
    GROUP BY sk_parlamentar, ano, trimestre
),

votos_por_sigla AS (
    SELECT
        t1.sk_parlamentar,
        t1.partido,
        COUNT(*) AS qt_votos
    FROM {{ ref('fct_votos') }} AS t1
    INNER JOIN {{ ref('votacoes_placar') }} AS t2
        ON t1.sk_votacao = t2.sk_votacao
    WHERE t1.partido IS NOT NULL
        AND t1.voto IN ('SIM', 'NAO', 'OBSTRUCAO')
        AND t2.legislatura = (SELECT legislatura FROM legislatura_corrente)
    GROUP BY t1.sk_parlamentar, t1.partido
),

partido_predominante AS (
    SELECT DISTINCT ON (sk_parlamentar)
        sk_parlamentar,
        partido
    FROM votos_por_sigla
    ORDER BY sk_parlamentar ASC, qt_votos DESC, partido ASC
),

comparado AS (
    SELECT
        t2.sk_parlamentar,
        t1.casa,
        t2.deputado_id_nk,
        t2.senador_id_nk,
        t2.nome,
        t2.uf,
        t4.partido
            AS partido_predominante,
        t1.radar_parlamentar_id_nk
            AS id_parlamentar_radar,
        t1.ano,
        t1.trimestre,
        t1.data_trimestre,
        t3.qt_votos
            AS qt_votos_oficial,
        t3.perc_governismo
            AS perc_governismo_oficial,
        t1.perc_governismo_trimestre
            AS perc_governismo_radar,
        t3.perc_governismo - t1.perc_governismo_trimestre
            AS diferenca_pp
    FROM radar AS t1
    INNER JOIN {{ ref('dim_parlamentares') }} AS t2
        ON t1.sk_parlamentar = t2.sk_parlamentar
    LEFT JOIN oficial AS t3
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
            WHEN t1.perc_governismo_oficial IS NULL THEN 'so_radar'
            ELSE 'ambas'
        END
            AS fonte_disponivel,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM comparado AS t1
)

SELECT * FROM final
