{{ config(tags=["politica"]) }}

-- Parlamentar com UF conhecida precisa ter região.
SELECT
    sk_parlamentar,
    uf
FROM {{ ref('dim_parlamentares') }}
WHERE
    uf IS NOT NULL
    AND uf <> '{{ var("null_string") }}'
    AND regiao IS NULL
