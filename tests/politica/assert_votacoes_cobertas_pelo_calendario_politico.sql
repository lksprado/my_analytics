{{ config(tags=["politica"]) }}

-- Toda votação datada precisa cair numa legislatura e num mandato presidencial do calendário.
SELECT
    t1.casa,
    t1.votacao_id_nk,
    t1.sk_data
FROM {{ ref('fct_votacoes') }} AS t1
LEFT JOIN {{ ref('dim_calendario_legislativo') }} AS t2
    ON t1.sk_data = t2.data_sk
WHERE
    t1.sk_data IS NOT NULL
    AND (t2.legislatura IS NULL OR t2.presidente IS NULL)
