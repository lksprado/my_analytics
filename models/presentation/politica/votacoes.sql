{{ config(
    tags=["politica"]
) }}

WITH
votacoes AS (
    SELECT * FROM {{ ref('fct_votacoes') }}
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
        t1.sessao_id,
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
        t1.modalidade_votacao,
        t1.descricao,
        t3.tipo_proposicao,
        t3.proposicao_id_nk,
        t3.identificacao
            AS identificacao_proposicao,
        t3.ementa,
        t3.data_proposicao,
        t1.fl_aprovada,
        CASE t1.fl_aprovada WHEN 1 THEN 'APROVADA' WHEN 0 THEN 'REJEITADA' ELSE 'NAO BINARIO' END
            AS resultado,
        -- O placar só existe onde há registro nominal aberto.
        CASE WHEN t1.modalidade_votacao = 'NOMINAL ABERTA' THEN t1.qt_votantes END
            AS qt_votantes,
        CASE WHEN t1.modalidade_votacao = 'NOMINAL ABERTA' THEN t1.qt_votos_sim END
            AS qt_votos_sim,
        CASE WHEN t1.modalidade_votacao = 'NOMINAL ABERTA' THEN t1.qt_votos_nao END
            AS qt_votos_nao,
        CASE WHEN t1.modalidade_votacao = 'NOMINAL ABERTA' THEN t1.qt_obstrucao END
            AS qt_obstrucao,
        CASE WHEN t1.modalidade_votacao = 'NOMINAL ABERTA' THEN t1.qt_abstencao END
            AS qt_abstencao,
        CASE WHEN t1.modalidade_votacao = 'NOMINAL ABERTA' THEN t1.qt_partidos END
            AS qt_partidos,
        CASE WHEN t1.modalidade_votacao = 'NOMINAL ABERTA' THEN t1.qt_votos_sim - t1.qt_votos_nao END
            AS margem,
        ROUND(100.0 * t1.qt_votos_sim / NULLIF(t1.qt_votantes, 0), 2)
            AS sim_pct,
        t1.orientacao_governo,
        t1.fl_governo_orientou,
        t1.fl_resultado_alinhado_governo,
        CASE t1.fl_resultado_alinhado_governo
            WHEN 1 THEN 'ALINHADO'
            WHEN 0 THEN 'NAO ALINHADO'
            ELSE t1.motivo_resultado_nao_classificado
        END
            AS resultado_alinhado_governo,
        CASE WHEN t1.modalidade_votacao = 'NOMINAL ABERTA' THEN (t1.qt_votos_sim = 0 OR t1.qt_votos_nao = 0)::INT END
            AS fl_unanimidade,
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
