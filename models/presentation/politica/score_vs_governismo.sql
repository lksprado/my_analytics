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
        ano,
        legislatura
    FROM {{ ref('votos_parlamentares') }}
    WHERE voto IN ('SIM', 'NAO', 'OBSTRUCAO')
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
        t3.uf,
        t3.regiao,
        t3.sk_partido,
        t3.partido
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
        t3.governismo_pct_modelo,
        t3.disciplina_pct,
        NULLIF(t3.qt_votos_governismo, 0)
            AS qt_votos_governismo,
        CASE WHEN t3.qt_votos_governismo > 0 THEN t3.qt_votos_alinhados_governo END
            AS qt_votos_alinhados_governo,
        NULLIF(t3.qt_votos_disciplina, 0)
            AS qt_votos_disciplina
    FROM score AS t1
    LEFT JOIN {{ ref('dim_parlamentares') }} AS t2
        ON t1.sk_parlamentar = t2.sk_parlamentar
    LEFT JOIN {{ ref('parlamentar_ano') }} AS t3
        ON t1.sk_parlamentar = t3.sk_parlamentar AND t1.ano = t3.ano
    LEFT JOIN legislatura_predominante AS t6
        ON t1.sk_parlamentar = t6.sk_parlamentar AND t1.ano = t6.ano
),

final AS (
    SELECT
        sk_parlamentar,
        deputado_id_nk,
        senador_id_nk,
        casa,
        nome,
        uf,
        regiao,
        sk_partido,
        partido_predominante,
        ano,
        legislatura,

        pontuacao,
        nota_base_votacoes,
        nota_base_gastos,
        nota_base_presenca,
        nota_base_privilegios,
        bonus_processos,
        bonus_producao_legislativa,
        bonus_articulacao_legislativa,
        fl_componentes_normalizados,

        qt_votos_governismo,
        qt_votos_alinhados_governo,
        governismo_pct_modelo,
        qt_votos_disciplina,
        disciplina_pct,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM base
)

SELECT * FROM final
