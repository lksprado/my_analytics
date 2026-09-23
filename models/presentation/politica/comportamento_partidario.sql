{{ config(
    tags=["politica"]
) }}

WITH
votos AS (
    SELECT
        casa,
        sk_partido,
        partido_rotulo,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato,
        sk_votacao,
        sk_parlamentar,
        voto,
        fl_seguiu_governo,
        fl_seguiu_partido
    FROM {{ ref('votos_parlamentares') }}
    WHERE sk_partido <> '{{ var("null_key") }}'
),

-- Rice ignora obstrução; votação com um só votante do partido fica de fora (daria Rice 1).
rice_por_votacao AS (
    SELECT
        casa,
        sk_partido,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato,
        sk_votacao,
        COUNT(*) FILTER (WHERE voto IN ('SIM', 'NAO'))
            AS qt_polarizados,
        ABS(
            COUNT(*) FILTER (WHERE voto = 'SIM')
            - COUNT(*) FILTER (WHERE voto = 'NAO')
        )::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE voto IN ('SIM', 'NAO')), 0)
            AS indice_rice
    FROM votos
    GROUP BY casa, sk_partido, ano, trimestre, legislatura, presidente, mandato, sk_votacao
),

coesao AS (
    SELECT
        casa,
        sk_partido,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato,
        COUNT(*) FILTER (WHERE qt_polarizados >= 2)
            AS qt_votacoes_coesao,
        ROUND(AVG(indice_rice) FILTER (WHERE qt_polarizados >= 2), 4)
            AS indice_rice_medio
    FROM rice_por_votacao
    GROUP BY casa, sk_partido, ano, trimestre, legislatura, presidente, mandato
),

-- Coesão não depende de orientação: cobre as duas casas.
bancada AS (
    SELECT
        casa,
        sk_partido,
        partido_rotulo,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato,
        COUNT(DISTINCT sk_parlamentar)
            AS qt_parlamentares,
        COUNT(DISTINCT sk_votacao)
            AS qt_votacoes,
        COUNT(*)
            AS qt_votos,
        NULLIF(COUNT(fl_seguiu_governo), 0)
            AS qt_votos_governismo,
        SUM(fl_seguiu_governo)
            AS qt_votos_alinhados_governo,
        NULLIF(COUNT(fl_seguiu_partido), 0)
            AS qt_votos_disciplina,
        SUM(fl_seguiu_partido)
            AS qt_votos_disciplinados
    FROM votos
    GROUP BY casa, sk_partido, partido_rotulo, ano, trimestre, legislatura, presidente, mandato
),

final AS (
    SELECT
        t1.casa,
        t1.sk_partido,
        t1.partido_rotulo
            AS partido,
        t1.legislatura,
        t1.presidente,
        t1.mandato,
        t1.ano,
        t1.trimestre,
        MAKE_DATE(t1.ano::INT, (t1.trimestre::INT - 1) * 3 + 1, 1)
            AS data_trimestre,
        t1.qt_parlamentares,
        t1.qt_votacoes,
        t1.qt_votos,
        t2.qt_votacoes_coesao,
        t2.indice_rice_medio,
        t1.qt_votos_governismo,
        t1.qt_votos_alinhados_governo,
        ROUND(100.0 * t1.qt_votos_alinhados_governo / t1.qt_votos_governismo, 2)
            AS perc_governismo,
        t1.qt_votos_disciplina,
        t1.qt_votos_disciplinados,
        ROUND(100.0 * t1.qt_votos_disciplinados / t1.qt_votos_disciplina, 2)
            AS perc_disciplina,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM bancada AS t1
    INNER JOIN coesao AS t2
        ON t1.casa = t2.casa
        AND t1.sk_partido = t2.sk_partido
        AND t1.ano = t2.ano
        AND t1.trimestre = t2.trimestre
        AND t1.legislatura IS NOT DISTINCT FROM t2.legislatura
        AND t1.presidente IS NOT DISTINCT FROM t2.presidente
        AND t1.mandato IS NOT DISTINCT FROM t2.mandato
)

SELECT * FROM final
