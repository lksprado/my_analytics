{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['votacao_id_fk', 'deputado_id_nk'],
    on_schema_change='append_new_columns',
    tags=["politica"]
) }}


WITH source AS (
    SELECT * FROM {{ source('camara','raw_camara_votos_deputados') }}
    -- A carga só acrescenta votações, e cada voto é imutável.
    {% if is_incremental() %}
        WHERE loaded_at_utc > (SELECT MAX(loaded_at_utc) FROM {{ this }})
    {% endif %}
),

renamed AS (
    SELECT
        deputado__id::INT                             AS deputado_id_nk,
        {{ clean_string('deputado__nome', 'upper') }} AS nome,
        deputado__siglauf                             AS uf,
        {{ clean_string("tipovoto", "upper") }}       AS voto,
        deputado__idlegislatura::INT                  AS legislatura,
        SPLIT_PART(url_votos, '/', 7)                 AS votacao_id_fk,
        SPLIT_PART(deputado__uripartido, '/', 7)::INT AS partido_id_fk,
        loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ           AS model_run_at
    FROM source
)

SELECT * FROM renamed
