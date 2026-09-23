{{ config(
    tags=["politica"]
) }}

WITH
votacoes AS (
    SELECT * FROM {{ ref('fct_votacoes') }}
    WHERE fl_nominal = 1
),

calendario AS (
    SELECT
        data_sk,
        data,
        ano,
        trimestre_do_ano,
        legislatura,
        presidente,
        mandato_presidencial
    FROM {{ ref('dim_calendario_legislativo') }}
),

proposicoes AS (
    SELECT
        sk_proposicao,
        proposicao_id_nk,
        tipo_proposicao,
        identificacao,
        ementa,
        data_proposicao
    FROM {{ ref('dim_proposicoes') }}
),

final AS (
    SELECT
        t1.sk_votacao,
        t1.votacao_id_nk,
        t1.casa,
        t2.data
            AS data_votacao,
        t2.ano,
        t2.trimestre_do_ano
            AS trimestre,
        t2.legislatura,
        t2.presidente,
        t2.mandato_presidencial
            AS mandato,
        t4.sigla_orgao,
        t4.tipo_orgao,
        t5.classe_votacao,
        t5.grupo_votacao,
        t1.descricao,
        t3.tipo_proposicao,
        t3.proposicao_id_nk,
        t3.identificacao
            AS identificacao_proposicao,
        t3.ementa,
        t3.data_proposicao,
        t1.fl_aprovada,
        CASE t1.fl_aprovada WHEN 1 THEN 'APROVADA' WHEN 0 THEN 'REJEITADA' END
            AS resultado,
        t1.qt_votantes,
        t1.qt_votos_sim,
        t1.qt_votos_nao,
        t1.qt_obstrucao,
        t1.qt_partidos,
        t1.qt_votos_sim - t1.qt_votos_nao
            AS margem,
        ROUND(100.0 * t1.qt_votos_sim / NULLIF(t1.qt_votantes, 0), 2)
            AS perc_sim,
        -- LIBERADO não é orientação: fica nulo, como quando o governo não se manifesta.
        CASE WHEN t1.fl_governo_orientou = 1 THEN t1.orientacao_governo END
            AS orientacao_governo,
        t1.fl_governo_orientou,
        t1.fl_governo_venceu,
        CASE
            WHEN t1.fl_governo_venceu = 1 THEN 'VENCEU'
            WHEN t1.fl_governo_venceu = 0 THEN 'PERDEU'
            WHEN t1.fl_governo_orientou = 1 THEN 'OBSTRUCAO'
            ELSE 'SEM ORIENTACAO'
        END
            AS resultado_governo,
        (t1.qt_votos_sim = 0 OR t1.qt_votos_nao = 0)::INT
            AS fl_unanimidade,
        (ROUND(100.0 * t1.qt_votos_sim / NULLIF(t1.qt_votantes, 0), 2) BETWEEN 45 AND 55)::INT
            AS fl_votacao_apertada,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM votacoes AS t1
    LEFT JOIN calendario AS t2
        ON t1.sk_data = t2.data_sk
    LEFT JOIN proposicoes AS t3
        ON t1.sk_proposicao = t3.sk_proposicao
    LEFT JOIN {{ ref('dim_orgaos') }} AS t4
        ON t1.sk_orgao = t4.sk_orgao
    LEFT JOIN {{ ref('dim_tipo_votacao') }} AS t5
        ON t1.sk_tipo_votacao = t5.sk_tipo_votacao
)

SELECT * FROM final
ORDER BY data_votacao DESC
