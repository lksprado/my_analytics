{{ config(tags=["politica"]) }}

-- Datas de virada: a legislatura começa em 1º/fev e a posse encosta no fim do mandato anterior.
WITH esperado (
    data, legislatura, sessao_legislativa, presidente, mandato_presidencial,
    fl_ano_eleicao_geral, fl_ano_eleicao_municipal
) AS (
    VALUES
    (DATE '1993-01-06', 49, 2, 'Itamar Franco', 1, FALSE, FALSE),
    (DATE '2016-08-30', 55, 2, 'Dilma Rousseff', 2, FALSE, TRUE),
    (DATE '2016-08-31', 55, 2, 'Michel Temer', 1, FALSE, TRUE),
    (DATE '2019-01-01', 55, 4, 'Jair Bolsonaro', 1, FALSE, FALSE),
    (DATE '2022-10-02', 56, 4, 'Jair Bolsonaro', 1, TRUE, FALSE),
    (DATE '2023-01-31', 56, 4, 'Luiz Inácio Lula da Silva', 3, FALSE, FALSE),
    (DATE '2023-02-01', 57, 1, 'Luiz Inácio Lula da Silva', 3, FALSE, FALSE),
    (DATE '2024-02-01', 57, 2, 'Luiz Inácio Lula da Silva', 3, FALSE, TRUE)
)

SELECT e.*
FROM esperado AS e
LEFT JOIN {{ ref('dim_calendario_legislativo') }} AS c
    ON e.data = c.data
WHERE
    c.data IS NULL
    OR c.legislatura IS DISTINCT FROM e.legislatura
    OR c.sessao_legislativa IS DISTINCT FROM e.sessao_legislativa
    OR c.presidente IS DISTINCT FROM e.presidente
    OR c.mandato_presidencial IS DISTINCT FROM e.mandato_presidencial
    OR c.fl_ano_eleicao_geral IS DISTINCT FROM e.fl_ano_eleicao_geral
    OR c.fl_ano_eleicao_municipal IS DISTINCT FROM e.fl_ano_eleicao_municipal
