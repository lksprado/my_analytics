{{ config(tags=["politica"]) }}

-- Toda votação datada precisa cair numa legislatura e num mandato presidencial das seeds.
WITH votacoes AS (
    SELECT
        casa,
        votacao_id_nk::TEXT AS votacao_id_nk,
        data_votacao
    FROM {{ ref('int_votacoes_camara_deduplicadas') }}
    UNION ALL
    SELECT
        casa,
        votacao_id_nk::TEXT,
        data_votacao
    FROM {{ ref('int_votacoes_senado_filtradas') }}
)

SELECT v.*
FROM votacoes AS v
WHERE
    v.data_votacao IS NOT NULL
    AND (
        NOT EXISTS (
            SELECT 1
            FROM {{ ref('seed_legislaturas') }} AS l
            WHERE v.data_votacao BETWEEN l.inicio::DATE AND l.fim::DATE
        )
        OR NOT EXISTS (
            SELECT 1
            FROM {{ ref('seed_executivo_presidente') }} AS p
            WHERE v.data_votacao BETWEEN p.inicio::DATE AND p.fim::DATE
        )
    )
