{{ config(
    tags=["politica"]
) }}

WITH
votacoes AS (
    SELECT
        sk_votacao,
        casa,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato
    FROM {{ ref('votacoes_placar') }}
),

votos_partido AS (
    SELECT
        t2.casa,
        t1.partido,
        t2.ano,
        t2.trimestre,
        t2.legislatura,
        t2.presidente,
        t2.mandato,
        t1.sk_votacao,
        t1.sk_parlamentar,
        t1.voto
    FROM {{ ref('fct_votos') }} AS t1
    INNER JOIN votacoes AS t2
        ON t1.sk_votacao = t2.sk_votacao
    WHERE t1.partido IS NOT NULL
        AND t1.voto IN ('SIM', 'NAO', 'OBSTRUCAO')
        AND t1.sk_parlamentar <> '{{ var("null_key") }}'
),

-- Rice ignora obstrução; votação com um só votante da sigla fica de fora (daria Rice 1).
rice_por_votacao AS (
    SELECT
        casa,
        partido,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato,
        sk_votacao,
        COUNT(*)
            AS qt_votos,
        COUNT(*) FILTER (WHERE voto IN ('SIM', 'NAO'))
            AS qt_polarizados,
        ABS(
            COUNT(*) FILTER (WHERE voto = 'SIM')
            - COUNT(*) FILTER (WHERE voto = 'NAO')
        )::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE voto IN ('SIM', 'NAO')), 0)
            AS indice_rice
    FROM votos_partido
    GROUP BY
        casa,
        partido,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato,
        sk_votacao
),

bancada AS (
    SELECT
        casa,
        partido,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato,
        COUNT(DISTINCT sk_parlamentar) AS qt_parlamentares
    FROM votos_partido
    GROUP BY casa, partido, ano, trimestre, legislatura, presidente, mandato
),

-- Coesão não depende de orientação: cobre as duas casas.
coesao AS (
    SELECT
        casa,
        partido,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato,
        COUNT(*)
            AS qt_votacoes,
        SUM(qt_votos)
            AS qt_votos,
        COUNT(*) FILTER (WHERE qt_polarizados >= 2)
            AS qt_votacoes_coesao,
        ROUND(AVG(indice_rice) FILTER (WHERE qt_polarizados >= 2), 4)
            AS indice_rice_medio
    FROM rice_por_votacao
    GROUP BY casa, partido, ano, trimestre, legislatura, presidente, mandato
),

governismo AS (
    SELECT
        casa,
        partido,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato,
        COUNT(*)                                  AS qt_votos_governismo,
        COUNT(*) FILTER (WHERE voto_alinhado = 1) AS qt_votos_alinhados_governo
    FROM {{ ref('governismo') }}
    WHERE partido IS NOT NULL
    GROUP BY casa, partido, ano, trimestre, legislatura, presidente, mandato
),

disciplina AS (
    SELECT
        casa,
        partido,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato,
        COUNT(*)                                       AS qt_votos_disciplina,
        COUNT(*) FILTER (WHERE voto_segue_partido = 1) AS qt_votos_disciplinados
    FROM {{ ref('disciplina_partidaria') }}
    WHERE partido IS NOT NULL
    GROUP BY casa, partido, ano, trimestre, legislatura, presidente, mandato
),

final AS (
    SELECT
        t1.casa,
        t1.partido,
        t1.legislatura,
        t1.presidente,
        t1.mandato,
        t1.ano,
        t1.trimestre,
        t4.qt_parlamentares,
        t1.qt_votacoes,
        t1.qt_votos,
        t1.qt_votacoes_coesao,
        t1.indice_rice_medio,
        t2.qt_votos_governismo,
        t2.qt_votos_alinhados_governo,
        ROUND(100.0 * t2.qt_votos_alinhados_governo / NULLIF(t2.qt_votos_governismo, 0), 2)
            AS perc_governismo,
        t3.qt_votos_disciplina,
        t3.qt_votos_disciplinados,
        ROUND(100.0 * t3.qt_votos_disciplinados / NULLIF(t3.qt_votos_disciplina, 0), 2)
            AS perc_disciplina,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM coesao AS t1
    INNER JOIN bancada AS t4
        ON t1.casa = t4.casa
        AND t1.partido = t4.partido
        AND t1.ano = t4.ano
        AND t1.trimestre = t4.trimestre
        AND t1.legislatura IS NOT DISTINCT FROM t4.legislatura
        AND t1.presidente IS NOT DISTINCT FROM t4.presidente
        AND t1.mandato IS NOT DISTINCT FROM t4.mandato
    LEFT JOIN governismo AS t2
        ON t1.casa = t2.casa
        AND t1.partido = t2.partido
        AND t1.ano = t2.ano
        AND t1.trimestre = t2.trimestre
        AND t1.legislatura IS NOT DISTINCT FROM t2.legislatura
        AND t1.presidente IS NOT DISTINCT FROM t2.presidente
        AND t1.mandato IS NOT DISTINCT FROM t2.mandato
    LEFT JOIN disciplina AS t3
        ON t1.casa = t3.casa
        AND t1.partido = t3.partido
        AND t1.ano = t3.ano
        AND t1.trimestre = t3.trimestre
        AND t1.legislatura IS NOT DISTINCT FROM t3.legislatura
        AND t1.presidente IS NOT DISTINCT FROM t3.presidente
        AND t1.mandato IS NOT DISTINCT FROM t3.mandato
)

SELECT * FROM final
