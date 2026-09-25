{{ config(tags=["politica"]) }}

-- A tabela de votações tem cada votação do fato uma vez, com a mesma modalidade e o mesmo placar.
WITH
fato AS (
    SELECT
        COUNT(*)                                                               AS qt_votacoes,
        COUNT(*) FILTER (WHERE modalidade_votacao = 'NOMINAL ABERTA')          AS qt_nominais_abertas,
        SUM(qt_votantes) FILTER (WHERE modalidade_votacao = 'NOMINAL ABERTA')  AS qt_votantes_abertas,
        SUM(qt_votantes) FILTER (WHERE modalidade_votacao = 'NOMINAL SECRETA') AS qt_votantes_secretas
    FROM {{ ref('fct_votacoes') }}
),

apresentacao AS (
    SELECT
        COUNT(*)                                                               AS qt_votacoes,
        COUNT(*) FILTER (WHERE modalidade_votacao = 'NOMINAL ABERTA')          AS qt_nominais_abertas,
        SUM(qt_votantes) FILTER (WHERE modalidade_votacao = 'NOMINAL ABERTA')  AS qt_votantes_abertas,
        SUM(qt_votantes) FILTER (WHERE modalidade_votacao = 'NOMINAL SECRETA') AS qt_votantes_secretas
    FROM {{ ref('votacoes') }}
)

SELECT
    f.qt_votacoes,
    a.qt_votacoes          AS qt_votacoes_apresentacao,
    f.qt_nominais_abertas,
    a.qt_nominais_abertas  AS qt_nominais_abertas_apresentacao,
    f.qt_votantes_abertas,
    a.qt_votantes_abertas  AS qt_votantes_abertas_apresentacao,
    f.qt_votantes_secretas,
    a.qt_votantes_secretas AS qt_votantes_secretas_apresentacao
FROM fato AS f
CROSS JOIN apresentacao AS a
WHERE
    f.qt_votacoes <> a.qt_votacoes
    OR f.qt_nominais_abertas <> a.qt_nominais_abertas
    OR f.qt_votantes_abertas <> a.qt_votantes_abertas
    OR f.qt_votantes_secretas IS DISTINCT FROM a.qt_votantes_secretas
