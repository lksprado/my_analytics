{{ config(tags=["politica"]) }}

-- A sessão legislativa do calendário é a do intervalo que contém a data.
SELECT
    c.data,
    c.legislatura,
    c.sessao_legislativa,
    s.legislatura        AS legislatura_da_sessao,
    s.sessao_legislativa AS sessao_da_dimensao
FROM {{ ref('dim_calendario_legislativo') }} AS c
LEFT JOIN {{ ref('dim_sessao_legislativa') }} AS s
    ON c.sk_sessao_legislativa = s.sk_sessao_legislativa
WHERE
    c.legislatura IS NOT NULL
    AND (
        s.sk_sessao_legislativa IS NULL
        OR c.data NOT BETWEEN s.inicio AND s.fim
        OR c.legislatura <> s.legislatura
        OR c.sessao_legislativa <> s.sessao_legislativa
    )
