{{ config(tags=["politica"]) }}

-- Toda proposição real precisa da identificação legível (ex.: PL 1234/2023).
SELECT
    sk_proposicao,
    casa,
    proposicao_id_nk
FROM {{ ref('dim_proposicoes') }}
WHERE
    sk_proposicao <> '{{ var("null_key") }}'
    AND identificacao IS NULL
