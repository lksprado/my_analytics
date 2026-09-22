{{ config(
    tags=["camara", "votacoes"]
) }}


WITH source AS (
    SELECT * FROM {{ source('camara','raw_camara_votos_deputados') }}
),

renamed AS (
    SELECT
        deputado__id::INT                                            AS deputado_id_nk,
        {{ clean_string('deputado__nome', 'upper') }}                AS nome,
        deputado__siglauf                                            AS uf,
        {{ clean_string("tipovoto", "upper") }}                      AS voto,
        deputado__idlegislatura::INT                                 AS legislatura,
        {{ clean_integer("SPLIT_PART(url_votos, '/', 7)") }}::BIGINT AS votacao_id_fk,
        SPLIT_PART(deputado__uripartido, '/', 7)::INT                AS partido_id_fk,
        loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ                          AS model_run_at
    FROM source
)

SELECT * FROM renamed
