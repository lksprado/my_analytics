{{ config(
    tags=["politica"]
) }}

WITH
proposicoes AS (
    SELECT * FROM {{ ref('dim_proposicoes') }}
    WHERE sk_proposicao <> '{{ var("null_key") }}'
),

votacoes AS (
    SELECT
        b.sk_proposicao,
        COUNT(*)                                                               AS qt_votacoes,
        COUNT(*) FILTER (WHERE v.modalidade_votacao <> 'SEM REGISTRO NOMINAL') AS qt_votacoes_nominais,
        COUNT(*) FILTER (WHERE v.fl_aprovada = 1)                              AS qt_votacoes_aprovadas,
        MIN(v.data_votacao)                                                    AS data_primeira_votacao,
        MAX(v.data_votacao)                                                    AS data_ultima_votacao
    FROM {{ ref('bridge_votacoes_proposicoes') }} AS b
    INNER JOIN {{ ref('votacoes') }} AS v
        ON b.sk_votacao = v.sk_votacao
    WHERE b.tipo_relacao = 'OBJETO'
    GROUP BY b.sk_proposicao
),

temas AS (
    SELECT
        b.sk_proposicao,
        COUNT(*)                                                                   AS qt_temas,
        STRING_AGG(t.tema, ', ' ORDER BY b.relevancia DESC NULLS LAST, t.tema ASC) AS temas
    FROM {{ ref('bridge_proposicoes_temas') }} AS b
    INNER JOIN {{ ref('dim_tema') }} AS t
        ON b.sk_tema = t.sk_tema
    WHERE b.origem_tema = 'PROPRIO'
    GROUP BY b.sk_proposicao
),

relacionadas AS (
    SELECT
        sk_proposicao,
        COUNT(*) AS qt_proposicoes_relacionadas
    FROM {{ ref('bridge_proposicoes_relacionadas') }}
    GROUP BY sk_proposicao
),

final AS (
    SELECT
        p.sk_proposicao,
        p.casa,
        p.proposicao_id_nk,
        p.tipo_proposicao,
        p.identificacao,
        p.ementa,
        p.data_proposicao                          AS data_apresentacao,
        EXTRACT(YEAR FROM p.data_proposicao)::INT  AS ano_apresentacao,
        p.situacao_atual,
        p.data_situacao_atual,
        p.fl_tramitando,
        p.regime,
        p.autoria,
        p.norma_gerada,
        d.nome                                     AS relator_atual,
        COALESCE(v.qt_votacoes, 0)                 AS qt_votacoes,
        COALESCE(v.qt_votacoes_nominais, 0)        AS qt_votacoes_nominais,
        COALESCE(v.qt_votacoes_aprovadas, 0)       AS qt_votacoes_aprovadas,
        v.data_primeira_votacao,
        v.data_ultima_votacao,
        COALESCE(t.qt_temas, 0)                    AS qt_temas,
        t.temas,
        COALESCE(r.qt_proposicoes_relacionadas, 0) AS qt_proposicoes_relacionadas,
        '{{ run_started_at }}'::TIMESTAMPTZ        AS model_run_at
    FROM proposicoes AS p
    LEFT JOIN votacoes AS v
        ON p.sk_proposicao = v.sk_proposicao
    LEFT JOIN temas AS t
        ON p.sk_proposicao = t.sk_proposicao
    LEFT JOIN relacionadas AS r
        ON p.sk_proposicao = r.sk_proposicao
    LEFT JOIN {{ ref('dim_parlamentares') }} AS d
        ON p.casa = 'CAMARA' AND p.relator_atual_id_nk = d.deputado_id_nk
)

SELECT * FROM final
