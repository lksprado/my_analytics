{{ config(tags=["politica"]) }}

-- A tabela de votos traz todos os registros e todas as ausências inferidas, cada um uma vez.
WITH
registros AS (
    SELECT COUNT(*) AS qt_linhas
    FROM {{ ref('fct_votos') }}
    WHERE sk_parlamentar <> '{{ var("null_key") }}'
),

inferidas AS (
    SELECT COUNT(*) AS qt_linhas
    FROM {{ ref('fct_presencas_plenario') }}
    WHERE fl_ausencia_inferida = 1
),

esperado AS (
    SELECT r.qt_linhas + i.qt_linhas AS qt_linhas
    FROM registros AS r
    CROSS JOIN inferidas AS i
),

obtido AS (
    SELECT COUNT(*) AS qt_linhas
    FROM {{ ref('votos_parlamentares') }}
)

SELECT
    e.qt_linhas AS esperado,
    o.qt_linhas AS obtido
FROM esperado AS e
CROSS JOIN obtido AS o
WHERE e.qt_linhas <> o.qt_linhas
