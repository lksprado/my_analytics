{{ config(
    tags=["camara", "parlamentar"]
) }}


WITH source AS (
    SELECT * FROM {{ source('camara','raw_camara_legislaturas') }}
),

renamed AS (
    SELECT
        idlegislatura::BIGINT               AS legislatura_id_nk,
        id::BIGINT                          AS deputado_id_fk,
        nome,
        siglauf                             AS uf,
        SPLIT_PART(uripartido, '/', 7)::INT AS partido_id_fk
    FROM source
    WHERE nome IS NOT NULL
)

SELECT * FROM renamed
