{{ config(
    tags=["politica"]
) }}

WITH
votos AS (
    SELECT
        casa,
        deputado_id_nk AS parlamentar_id_nk,
        votacao_id_fk  AS votacao_id_nk,
        partido_id_senado,
        partido,
        partido_nome,
        codigo_voto
    FROM {{ ref('int_votos_camara_normalizados') }}
    UNION ALL
    SELECT
        casa,
        senador_id_nk,
        votacao_id_fk::TEXT,
        partido_id_senado,
        partido,
        partido_nome,
        codigo_voto
    FROM {{ ref('int_votos_senado_normalizados') }}
)

SELECT
    v.casa,
    v.parlamentar_id_nk,
    v.votacao_id_nk,
    v.partido_id_senado,
    v.partido,
    v.partido_nome,
    v.codigo_voto,
    t.posicao                           AS voto,
    t.categoria,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM votos AS v
LEFT JOIN {{ ref('seed_tipos_voto') }} AS t
    ON v.casa = t.casa AND v.codigo_voto = t.codigo_origem
