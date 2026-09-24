{{ config(tags=["politica"]) }}

-- Parlamentar com UF conhecida precisa ter região.
SELECT
    sk_parlamentar,
    uf_mandato_recente
FROM {{ ref('dim_parlamentares') }}
WHERE
    uf_mandato_recente IS NOT NULL
    AND uf_mandato_recente <> '{{ var("null_string") }}'
    AND regiao IS NULL
