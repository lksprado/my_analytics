{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['casa', 'votacao_id_nk', 'parlamentar_id_nk'],
    post_hook="CREATE INDEX IF NOT EXISTS idx_int_votos_unificados_votacao ON {{ this }} (casa, votacao_id_nk)",
    on_schema_change='append_new_columns',
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
        uf,
        codigo_voto,
        loaded_at_utc
    FROM {{ ref('int_votos_camara_normalizados') }}
    {% if is_incremental() %}
        -- A Câmara só acrescenta votos; o Senado, quando recarrega, volta inteiro.
        WHERE
            loaded_at_utc > (
                SELECT COALESCE(MAX(loaded_at_utc), '1900-01-01') FROM {{ this }}
                WHERE casa = 'CAMARA'
            )
    {% endif %}
    UNION ALL
    SELECT
        casa,
        senador_id_nk,
        votacao_id_fk::TEXT,
        partido_id_senado,
        partido,
        partido_nome,
        uf,
        codigo_voto,
        loaded_at_utc
    FROM {{ ref('int_votos_senado_normalizados') }}
    {% if is_incremental() %}
        WHERE
            loaded_at_utc > (
                SELECT COALESCE(MAX(loaded_at_utc), '1900-01-01') FROM {{ this }}
                WHERE casa = 'SENADO'
            )
    {% endif %}
)

SELECT
    v.casa,
    v.parlamentar_id_nk,
    v.votacao_id_nk,
    v.partido_id_senado,
    v.partido,
    v.partido_nome,
    v.uf,
    v.codigo_voto,
    t.posicao                           AS voto,
    t.categoria,
    v.loaded_at_utc,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM votos AS v
LEFT JOIN {{ ref('seed_tipos_voto') }} AS t
    ON v.casa = t.casa AND v.codigo_voto = t.codigo_origem
