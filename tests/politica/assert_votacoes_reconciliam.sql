{{ config(tags=["politica"]) }}

-- A tabela de votações tem cada votação do fato uma vez, com a mesma modalidade.
WITH
fato AS (
    SELECT
        COUNT(*)                                                              AS qt_votacoes,
        COUNT(*) FILTER (WHERE modalidade_votacao = 'NOMINAL ABERTA')         AS qt_nominais_abertas,
        SUM(qt_votantes) FILTER (WHERE modalidade_votacao = 'NOMINAL ABERTA') AS qt_votantes
    FROM {{ ref('fct_votacoes') }}
),

apresentacao AS (
    SELECT
        COUNT(*)                                                      AS qt_votacoes,
        COUNT(*) FILTER (WHERE modalidade_votacao = 'NOMINAL ABERTA') AS qt_nominais_abertas,
        SUM(qt_votantes)                                              AS qt_votantes
    FROM {{ ref('votacoes') }}
)

SELECT
    f.qt_votacoes,
    a.qt_votacoes         AS qt_votacoes_apresentacao,
    f.qt_nominais_abertas,
    a.qt_nominais_abertas AS qt_nominais_abertas_apresentacao,
    f.qt_votantes,
    a.qt_votantes         AS qt_votantes_apresentacao
FROM fato AS f
CROSS JOIN apresentacao AS a
WHERE
    f.qt_votacoes <> a.qt_votacoes
    OR f.qt_nominais_abertas <> a.qt_nominais_abertas
    OR f.qt_votantes <> a.qt_votantes
