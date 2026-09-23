{{ config(
    tags=["politica"]
) }}


WITH source AS (
    SELECT * FROM {{ source('camara','raw_camara_proposicao_tema') }}
),

renamed AS (
    SELECT
        SPLIT_PART(url_temas, '/', 7)       AS proposicao_id_nk,
        {{ clean_string("tema", "upper") }} AS tema,
        codtema::BIGINT                     AS codigo_tema,
        relevancia::INT                     AS relevancia,
        loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM source
)

SELECT * FROM renamed
