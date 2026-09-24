{{ config(tags=["politica"]) }}

-- Um parlamentar pertence a uma só casa: nenhuma tabela mistura casas para a mesma chave.
WITH
casas AS (
    SELECT
        sk_parlamentar,
        casa
    FROM {{ ref('fct_votos') }}
    UNION
    SELECT
        sk_parlamentar,
        casa
    FROM {{ ref('fct_presencas_plenario') }}
    UNION
    SELECT
        sk_parlamentar,
        casa
    FROM {{ ref('parlamentar_legislatura') }}
    UNION
    SELECT
        sk_parlamentar,
        casa
    FROM {{ ref('fct_indicadores_externos') }}
)

SELECT
    c.sk_parlamentar,
    c.casa,
    d.casa AS casa_dimensao
FROM casas AS c
INNER JOIN {{ ref('dim_parlamentares') }} AS d
    ON c.sk_parlamentar = d.sk_parlamentar
WHERE
    c.sk_parlamentar <> '{{ var("null_key") }}'
    AND c.casa <> d.casa
