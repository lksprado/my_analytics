{{ config(
    tags=["politica"]
) }}

WITH
score AS (
    SELECT
        sk_parlamentar,
        ano,
        pontuacao,
        nota_base_votacoes,
        nota_base_gastos,
        nota_base_presenca,
        nota_base_privilegios,
        bonus_processos,
        bonus_producao_legislativa,
        bonus_articulacao_legislativa,
        -- Escala detectada pelo teto do ano: em 2026 a origem passou a normalizar em 0-1.
        (MAX(nota_base_presenca) OVER (PARTITION BY ano) <= 1)::INT
            AS fl_componentes_normalizados
    FROM {{ ref('fct_ranking_politicos_anual') }}
    WHERE sk_parlamentar <> '{{ var("null_key") }}'
        AND ano IS NOT NULL
),

votos_ano AS (
    SELECT
        sk_parlamentar,
        sk_partido,
        partido_rotulo,
        ano,
        legislatura,
        fl_seguiu_governo,
        fl_seguiu_partido
    FROM {{ ref('votos_parlamentares') }}
),

metricas AS (
    SELECT
        sk_parlamentar,
        ano,
        NULLIF(COUNT(fl_seguiu_governo), 0)
            AS qt_votos_governismo,
        SUM(fl_seguiu_governo)
            AS qt_votos_alinhados_governo,
        ROUND(100.0 * SUM(fl_seguiu_governo) / NULLIF(COUNT(fl_seguiu_governo), 0), 2)
            AS perc_governismo,
        NULLIF(COUNT(fl_seguiu_partido), 0)
            AS qt_votos_disciplina,
        ROUND(100.0 * SUM(fl_seguiu_partido) / NULLIF(COUNT(fl_seguiu_partido), 0), 2)
            AS perc_disciplina
    FROM votos_ano
    GROUP BY sk_parlamentar, ano
),

votos_por_partido AS (
    SELECT
        sk_parlamentar,
        ano,
        sk_partido,
        partido_rotulo,
        COUNT(*) AS qt_votos
    FROM votos_ano
    WHERE sk_partido <> '{{ var("null_key") }}'
    GROUP BY sk_parlamentar, ano, sk_partido, partido_rotulo
),

-- Quem trocou de partido no meio do ano fica com o majoritário; desempate alfabético.
partido_predominante AS (
    SELECT DISTINCT ON (sk_parlamentar, ano)
        sk_parlamentar,
        ano,
        sk_partido,
        partido_rotulo
    FROM votos_por_partido
    ORDER BY sk_parlamentar ASC, ano ASC, qt_votos DESC, partido_rotulo ASC
),

votos_por_legislatura AS (
    SELECT
        sk_parlamentar,
        ano,
        legislatura,
        COUNT(*) AS qt_votos
    FROM votos_ano
    GROUP BY sk_parlamentar, ano, legislatura
),

-- No ano de virada de legislatura vale a de maior volume.
legislatura_predominante AS (
    SELECT DISTINCT ON (sk_parlamentar, ano)
        sk_parlamentar,
        ano,
        legislatura
    FROM votos_por_legislatura
    ORDER BY sk_parlamentar ASC, ano ASC, qt_votos DESC, legislatura DESC
),

base AS (
    SELECT
        t1.sk_parlamentar,
        t1.ano,
        t2.deputado_id_nk,
        t2.senador_id_nk,
        t2.casa,
        t2.nome,
        t2.uf,
        t2.regiao,
        t5.sk_partido,
        t5.partido_rotulo
            AS partido_predominante,
        t6.legislatura,
        t1.pontuacao,
        t1.nota_base_votacoes,
        t1.nota_base_gastos,
        t1.nota_base_presenca,
        t1.nota_base_privilegios,
        t1.bonus_processos,
        t1.bonus_producao_legislativa,
        t1.bonus_articulacao_legislativa,
        t1.fl_componentes_normalizados,
        t3.qt_votos_governismo,
        t3.qt_votos_alinhados_governo,
        t3.perc_governismo,
        t3.qt_votos_disciplina,
        t3.perc_disciplina
    FROM score AS t1
    LEFT JOIN {{ ref('dim_parlamentares') }} AS t2
        ON t1.sk_parlamentar = t2.sk_parlamentar
    LEFT JOIN metricas AS t3
        ON t1.sk_parlamentar = t3.sk_parlamentar AND t1.ano = t3.ano
    LEFT JOIN partido_predominante AS t5
        ON t1.sk_parlamentar = t5.sk_parlamentar AND t1.ano = t5.ano
    LEFT JOIN legislatura_predominante AS t6
        ON t1.sk_parlamentar = t6.sk_parlamentar AND t1.ano = t6.ano
),

-- Percentis na mesma população; o corte de 30 votos tira governismo sem base.
elegiveis AS (
    SELECT *
    FROM base
    WHERE pontuacao IS NOT NULL
        AND qt_votos_governismo >= 30
),

medianas AS (
    SELECT
        casa,
        ano,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY perc_governismo)
            AS mediana_governismo,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY pontuacao)
            AS mediana_pontuacao
    FROM elegiveis
    GROUP BY casa, ano
),

qualificados AS (
    SELECT
        t1.sk_parlamentar,
        t1.ano,
        t2.mediana_governismo,
        t2.mediana_pontuacao,
        PERCENT_RANK() OVER (PARTITION BY t1.casa, t1.ano ORDER BY t1.perc_governismo)
            AS percentil_governismo,
        PERCENT_RANK() OVER (PARTITION BY t1.casa, t1.ano ORDER BY t1.pontuacao)
            AS percentil_pontuacao
    FROM elegiveis AS t1
    INNER JOIN medianas AS t2
        ON t1.casa = t2.casa AND t1.ano = t2.ano
),

final AS (
    SELECT
        t1.sk_parlamentar,
        t1.deputado_id_nk,
        t1.senador_id_nk,
        t1.casa,
        t1.nome,
        t1.uf,
        t1.regiao,
        t1.sk_partido,
        t1.partido_predominante,
        t1.ano,
        t1.legislatura,

        t1.pontuacao,
        t1.nota_base_votacoes,
        t1.nota_base_gastos,
        t1.nota_base_presenca,
        t1.nota_base_privilegios,
        t1.bonus_processos,
        t1.bonus_producao_legislativa,
        t1.bonus_articulacao_legislativa,
        t1.fl_componentes_normalizados,

        t1.qt_votos_governismo,
        t1.qt_votos_alinhados_governo,
        t1.perc_governismo,
        t1.qt_votos_disciplina,
        t1.perc_disciplina,

        ROUND(t2.percentil_governismo::NUMERIC, 4)
            AS percentil_governismo,
        ROUND(t2.percentil_pontuacao::NUMERIC, 4)
            AS percentil_pontuacao,
        ROUND(t2.percentil_pontuacao::NUMERIC, 4) - ROUND(t2.percentil_governismo::NUMERIC, 4)
            AS gap_percentil,
        CASE
            WHEN t2.sk_parlamentar IS NULL THEN NULL
            WHEN t1.perc_governismo >= t2.mediana_governismo
                AND t1.pontuacao >= t2.mediana_pontuacao THEN 'GOVERNISTA BEM AVALIADO'
            WHEN t1.perc_governismo >= t2.mediana_governismo THEN 'GOVERNISTA MAL AVALIADO'
            WHEN t1.pontuacao >= t2.mediana_pontuacao THEN 'OPOSICAO BEM AVALIADA'
            ELSE 'OPOSICAO MAL AVALIADA'
        END
            AS quadrante,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM base AS t1
    LEFT JOIN qualificados AS t2
        ON t1.sk_parlamentar = t2.sk_parlamentar AND t1.ano = t2.ano
)

SELECT * FROM final
