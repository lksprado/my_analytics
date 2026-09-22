{{ config(
    tags=["camara", "parlamentar", "score", "votacoes"]
) }}

WITH
governismo AS (
    SELECT * FROM {{ ref('governismo_por_parlamentar_legislatura_ajustado') }}
),

votos_legislatura AS (
    SELECT
        t1.sk_parlamentar,
        t1.partido,
        t2.casa,
        t2.legislatura,
        t1.sk_votacao
    FROM {{ ref('fct_votos') }} AS t1
    INNER JOIN {{ ref('votacoes_placar') }} AS t2
        ON t1.sk_votacao = t2.sk_votacao
    WHERE t1.sk_parlamentar <> '{{ var("null_key") }}'
),

-- Participação sobre todas as votações nominais da casa na legislatura, não só as orientadas
-- pelo Governo: é o denominador que mede ausência.
participacao AS (
    SELECT
        sk_parlamentar,
        legislatura,
        COUNT(*)                   AS qt_votos_legislatura,
        COUNT(DISTINCT sk_votacao) AS qt_votacoes_legislatura
    FROM votos_legislatura
    GROUP BY sk_parlamentar, legislatura
),

universo AS (
    SELECT
        casa,
        legislatura,
        COUNT(DISTINCT sk_votacao) AS qt_votacoes_casa
    FROM votos_legislatura
    GROUP BY casa, legislatura
),

votos_por_sigla AS (
    SELECT
        sk_parlamentar,
        legislatura,
        partido,
        COUNT(*) AS qt_votos
    FROM votos_legislatura
    WHERE partido IS NOT NULL
    GROUP BY sk_parlamentar, legislatura, partido
),

-- Quem trocou de partido no meio do mandato fica com a sigla majoritária; desempate alfabético.
partido_predominante AS (
    SELECT DISTINCT ON (sk_parlamentar, legislatura)
        sk_parlamentar,
        legislatura,
        partido
    FROM votos_por_sigla
    ORDER BY sk_parlamentar ASC, legislatura ASC, qt_votos DESC, partido ASC
),

disciplina AS (
    SELECT
        sk_parlamentar,
        legislatura,
        COUNT(*)
            AS qt_votos_disciplina,
        COUNT(*) FILTER (WHERE voto_segue_partido = 1)
            AS qt_votos_disciplinados,
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE voto_segue_partido = 1)::NUMERIC
            / NULLIF(COUNT(*), 0), 2
        )
            AS perc_disciplina
    FROM {{ ref('disciplina_partidaria') }}
    GROUP BY sk_parlamentar, legislatura
),

-- O Ranking dos Políticos não tem recorte por legislatura: a pontuação é a foto do mandato
-- corrente. Repeti-la nas legislaturas antigas sugeriria uma série histórica que não existe.
legislatura_corrente AS (
    SELECT MAX(legislatura) AS legislatura
    FROM {{ ref('votacoes_placar') }}
),

atributos AS (
    SELECT
        t1.sk_parlamentar,
        t1.deputado_id_nk,
        t1.senador_id_nk,
        t1.casa,
        t2.nome,
        t2.nome_completo,
        t2.sexo,
        t2.uf,
        t6.partido
            AS partido_predominante,
        t1.legislatura,

        t3.qt_votos_legislatura,
        t3.qt_votacoes_legislatura,
        t4.qt_votacoes_casa,

        t1.qt_votos
            AS qt_votos_governismo,
        t1.qt_votos_alinhados
            AS qt_votos_alinhados_governo,
        t1.perc_governismo,
        t1.score_governismo_ponderado,

        t5.qt_votos_disciplina,
        t5.qt_votos_disciplinados,
        t5.perc_disciplina,

        t7.pontuacao_geral,
        t7.ranking_geral,
        t7.ranking_casa,
        t7.ranking_partido,
        t7.ranking_estado,
        t7.ranking_casa_estado
    FROM governismo AS t1
    LEFT JOIN {{ ref('dim_parlamentares') }} AS t2
        ON t1.sk_parlamentar = t2.sk_parlamentar
    LEFT JOIN participacao AS t3
        ON t1.sk_parlamentar = t3.sk_parlamentar AND t1.legislatura = t3.legislatura
    LEFT JOIN universo AS t4
        ON t1.casa = t4.casa AND t1.legislatura = t4.legislatura
    LEFT JOIN disciplina AS t5
        ON t1.sk_parlamentar = t5.sk_parlamentar AND t1.legislatura = t5.legislatura
    LEFT JOIN partido_predominante AS t6
        ON t1.sk_parlamentar = t6.sk_parlamentar AND t1.legislatura = t6.legislatura
    LEFT JOIN {{ ref('dim_parlamentares_score') }} AS t7
        ON t1.sk_parlamentar = t7.sk_parlamentar
        AND t1.legislatura = (SELECT legislatura FROM legislatura_corrente)
),

-- Os dois percentis saem da mesma população para que o gap signifique alguma coisa: quem tem
-- pontuação e pelo menos 50 votos orientados na legislatura. Como pontuacao_geral só existe
-- para a legislatura corrente, as quatro colunas ficam nulas nas anteriores.
elegiveis AS (
    SELECT *
    FROM atributos
    WHERE pontuacao_geral IS NOT NULL
        AND qt_votos_governismo >= 50
),

medianas AS (
    SELECT
        casa,
        legislatura,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY perc_governismo)
            AS mediana_governismo,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY pontuacao_geral)
            AS mediana_pontuacao
    FROM elegiveis
    GROUP BY casa, legislatura
),

qualificados AS (
    SELECT
        t1.sk_parlamentar,
        t1.legislatura,
        t2.mediana_governismo,
        t2.mediana_pontuacao,
        PERCENT_RANK() OVER (PARTITION BY t1.casa, t1.legislatura ORDER BY t1.perc_governismo)
            AS percentil_governismo,
        PERCENT_RANK() OVER (PARTITION BY t1.casa, t1.legislatura ORDER BY t1.pontuacao_geral)
            AS percentil_pontuacao
    FROM elegiveis AS t1
    INNER JOIN medianas AS t2
        ON t1.casa = t2.casa AND t1.legislatura = t2.legislatura
),

final AS (
    SELECT
        t1.*,
        ROUND(100.0 * t1.qt_votacoes_legislatura / NULLIF(t1.qt_votacoes_casa, 0), 2)
            AS perc_participacao,
        ROUND(t2.percentil_governismo::NUMERIC, 4)
            AS percentil_governismo,
        ROUND(t2.percentil_pontuacao::NUMERIC, 4)
            AS percentil_pontuacao,
        ROUND(t2.percentil_pontuacao::NUMERIC, 4) - ROUND(t2.percentil_governismo::NUMERIC, 4)
            AS gap_percentil,
        CASE
            WHEN t2.sk_parlamentar IS NULL THEN NULL
            WHEN t1.perc_governismo >= t2.mediana_governismo
                AND t1.pontuacao_geral >= t2.mediana_pontuacao THEN 'governista bem avaliado'
            WHEN t1.perc_governismo >= t2.mediana_governismo THEN 'governista mal avaliado'
            WHEN t1.pontuacao_geral >= t2.mediana_pontuacao THEN 'oposicao bem avaliada'
            ELSE 'oposicao mal avaliada'
        END
            AS quadrante,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM atributos AS t1
    LEFT JOIN qualificados AS t2
        ON t1.sk_parlamentar = t2.sk_parlamentar AND t1.legislatura = t2.legislatura
)

SELECT * FROM final
