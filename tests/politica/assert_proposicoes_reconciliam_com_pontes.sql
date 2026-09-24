{{ config(tags=["politica"]) }}

-- As contagens da tabela de proposições saem das pontes, sem dupla contagem.
WITH
votacoes AS (
    SELECT COUNT(*) AS qt
    FROM {{ ref('bridge_votacoes_proposicoes') }}
    WHERE tipo_relacao = 'OBJETO'
),

temas AS (
    SELECT
        COUNT(*)                                        AS qt,
        COUNT(*) FILTER (WHERE origem_tema = 'PROPRIO') AS qt_proprios
    FROM {{ ref('bridge_proposicoes_temas') }}
),

proposicoes AS (
    SELECT
        SUM(qt_votacoes) AS qt_votacoes,
        SUM(qt_temas)    AS qt_temas
    FROM {{ ref('proposicoes') }}
),

proposicoes_temas AS (
    SELECT COUNT(*) AS qt
    FROM {{ ref('proposicoes_temas') }}
)

SELECT
    p.qt_votacoes,
    v.qt          AS qt_votacoes_ponte,
    p.qt_temas,
    t.qt_proprios AS qt_temas_proprios_ponte,
    pt.qt         AS qt_linhas_proposicoes_temas
FROM proposicoes AS p
CROSS JOIN votacoes AS v
CROSS JOIN temas AS t
CROSS JOIN proposicoes_temas AS pt
WHERE
    p.qt_votacoes <> v.qt
    OR p.qt_temas <> t.qt_proprios
    OR pt.qt <> t.qt
