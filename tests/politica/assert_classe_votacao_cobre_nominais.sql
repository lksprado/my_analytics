{{ config(tags=["politica"]) }}

-- A classificação pela descrição precisa reconhecer ao menos 85% das votações nominais de cada casa.
SELECT
    t1.casa,
    ROUND(100.0 * COUNT(*) FILTER (WHERE t2.classe_votacao = 'OUTROS') / COUNT(*), 1) AS perc_outros
FROM {{ ref('fct_votacoes') }} AS t1
INNER JOIN {{ ref('dim_tipo_votacao') }} AS t2
    ON t1.sk_tipo_votacao = t2.sk_tipo_votacao
WHERE t1.fl_nominal = 1
GROUP BY t1.casa
HAVING COUNT(*) FILTER (WHERE t2.classe_votacao = 'OUTROS') > 0.15 * COUNT(*)
