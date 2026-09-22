{{ config(
    enabled=false,
    tags=["camara", "senado", "parlamentar", "radar", "votacoes"]
) }}

WITH
legislatura_corrente AS (
    SELECT MAX(legislatura) AS legislatura
    FROM {{ ref('votacoes_placar') }}
),

-- As três colunas de legislatura do radar são constantes nas doze linhas trimestrais.
radar AS (
    SELECT DISTINCT
        casa,
        parlamentar_id_nk,
        id_parlamentar_radar,
        nome_eleitoral,
        qt_votos_legislatura,
        qt_votos_alinhados_legislatura,
        perc_governismo_legislatura
    FROM {{ ref('int_radar_governismo') }}
),

-- O radar cobre 2023 T1 a 2025 T4. Sem esse recorte o comparativo mede a diferença de janela
-- em vez da de método: o erro absoluto médio sobe de 0,62 pp para 1,09 pp só por conta de 2026.
janela_radar AS (
    SELECT DISTINCT
        ano,
        trimestre
    FROM {{ ref('int_radar_governismo') }}
),

oficial_janela AS (
    SELECT
        t1.sk_parlamentar,
        COUNT(*)
            AS qt_votos,
        COUNT(*) FILTER (WHERE t1.voto_alinhado = 1)
            AS qt_votos_alinhados
    FROM {{ ref('governismo') }} AS t1
    INNER JOIN janela_radar AS t2
        ON t1.ano = t2.ano AND t1.trimestre = t2.trimestre
    WHERE t1.legislatura = (SELECT legislatura FROM legislatura_corrente)
    GROUP BY t1.sk_parlamentar
),

oficial_completa AS (
    SELECT
        sk_parlamentar,
        ROUND(100.0 * COUNT(*) FILTER (WHERE voto_alinhado = 1) / NULLIF(COUNT(*), 0), 2)
            AS perc_governismo
    FROM {{ ref('governismo') }}
    WHERE legislatura = (SELECT legislatura FROM legislatura_corrente)
    GROUP BY sk_parlamentar
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
        t5.partido
            AS partido_predominante,
        t1.id_parlamentar_radar,
        t1.nome_eleitoral
            AS nome_eleitoral_radar,
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
        ON t1.casa = t2.casa
        AND t1.parlamentar_id_nk = COALESCE(t2.deputado_id_nk, t2.senador_id_nk)
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
        ABS(t1.diferenca_pp) > 5
            AS flag_divergencia_relevante,
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
