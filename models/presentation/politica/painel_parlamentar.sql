{{ config(
    tags=["politica"]
) }}

WITH
votos AS (
    SELECT
        sk_parlamentar,
        sk_partido,
        partido_rotulo,
        casa,
        legislatura,
        sk_votacao,
        fl_seguiu_governo,
        fl_seguiu_partido,
        fl_votou_com_resultado
    FROM {{ ref('votos_parlamentares') }}
),

metricas AS (
    SELECT
        sk_parlamentar,
        casa,
        legislatura,
        COUNT(*)                                 AS qt_votos_legislatura,
        COUNT(DISTINCT sk_votacao)               AS qt_votacoes_legislatura,
        COUNT(fl_seguiu_governo)                 AS qt_votos_governismo,
        COALESCE(SUM(fl_seguiu_governo), 0)      AS qt_votos_alinhados_governo,
        COUNT(fl_seguiu_partido)                 AS qt_votos_disciplina,
        COALESCE(SUM(fl_seguiu_partido), 0)      AS qt_votos_disciplinados,
        COUNT(fl_votou_com_resultado)            AS qt_votos_com_resultado,
        COALESCE(SUM(fl_votou_com_resultado), 0) AS qt_votos_vencedores
    FROM votos
    GROUP BY sk_parlamentar, casa, legislatura
),

governismo AS (
    SELECT
        *,
        ROUND(100.0 * qt_votos_alinhados_governo / NULLIF(qt_votos_governismo, 0), 2)
            AS governismo_pct_modelo
    FROM metricas
),

-- Denominador: todas as votações nominais da casa, não só as orientadas.
universo AS (
    SELECT
        casa,
        legislatura,
        COUNT(DISTINCT sk_votacao) AS qt_votacoes_casa
    FROM votos
    GROUP BY casa, legislatura
),

votos_por_partido AS (
    SELECT
        sk_parlamentar,
        legislatura,
        sk_partido,
        partido_rotulo,
        COUNT(*) AS qt_votos
    FROM votos
    WHERE sk_partido <> '{{ var("null_key") }}'
    GROUP BY sk_parlamentar, legislatura, sk_partido, partido_rotulo
),

-- Quem trocou de partido no meio do mandato fica com o majoritário; desempate alfabético.
partido_predominante AS (
    SELECT DISTINCT ON (sk_parlamentar, legislatura)
        sk_parlamentar,
        legislatura,
        sk_partido,
        partido_rotulo
    FROM votos_por_partido
    ORDER BY sk_parlamentar ASC, legislatura ASC, qt_votos DESC, partido_rotulo ASC
),

-- O Ranking é foto do mandato corrente: só entra na legislatura atual.
legislatura_corrente AS (
    SELECT MAX(legislatura) AS legislatura
    FROM {{ ref('votacoes') }}
),

atributos AS (
    SELECT
        t1.sk_parlamentar,
        t2.deputado_id_nk,
        t2.senador_id_nk,
        t1.casa,
        t2.nome,
        t2.nome_completo,
        t2.sexo,
        t2.uf,
        t2.regiao,
        t6.sk_partido,
        t6.partido_rotulo
            AS partido_predominante,
        t1.legislatura,

        t1.qt_votos_legislatura,
        t1.qt_votacoes_legislatura,
        t4.qt_votacoes_casa,

        t1.qt_votos_governismo,
        t1.qt_votos_alinhados_governo,
        t1.governismo_pct_modelo,

        t1.qt_votos_disciplina,
        t1.qt_votos_disciplinados,
        ROUND(100.0 * t1.qt_votos_disciplinados / NULLIF(t1.qt_votos_disciplina, 0), 2)
            AS disciplina_pct,

        t1.qt_votos_com_resultado,
        t1.qt_votos_vencedores,
        ROUND(100.0 * t1.qt_votos_vencedores / NULLIF(t1.qt_votos_com_resultado, 0), 2)
            AS votos_vencedores_pct,

        t7.pontuacao_geral,
        t7.ranking_geral,
        t7.ranking_casa,
        t7.ranking_partido,
        t7.ranking_estado,
        t7.ranking_casa_estado
    FROM governismo AS t1
    LEFT JOIN {{ ref('dim_parlamentares') }} AS t2
        ON t1.sk_parlamentar = t2.sk_parlamentar
    LEFT JOIN universo AS t4
        ON t1.casa = t4.casa AND t1.legislatura = t4.legislatura
    LEFT JOIN partido_predominante AS t6
        ON t1.sk_parlamentar = t6.sk_parlamentar AND t1.legislatura = t6.legislatura
    LEFT JOIN {{ ref('fct_ranking_politicos') }} AS t7
        ON t1.sk_parlamentar = t7.sk_parlamentar
        AND t1.legislatura = (SELECT legislatura FROM legislatura_corrente)
),

final AS (
    SELECT
        *,
        ROUND(100.0 * qt_votacoes_legislatura / NULLIF(qt_votacoes_casa, 0), 2)
            AS participacao_pct,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM atributos
)

SELECT * FROM final
