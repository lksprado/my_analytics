{{ config(
    materialized='ephemeral',
    tags=["camara", "parlamentar"]
) }}

WITH source AS (
    SELECT * FROM {{ source('camara','raw_camara_deputados') }}
),

renamed AS (
    SELECT
        id::BIGINT                                                AS deputado_id_nk,
        {{ clean_string('nomecivil', 'upper') }}                  AS nome_civil,
        {{ clean_string('ultimostatus_nomeeleitoral', 'upper') }} AS nome_eleitoral,
        {{ clean_string('sexo', 'upper') }}                       AS sexo,
        CASE 
            WHEN redesocial = '[]' THEN NULL 
            ELSE redesocial
        END                                                       AS rede_social,
        TO_DATE(datanascimento, 'YYYY-MM-DD')                     AS data_nascimento,
        TO_DATE(datafalecimento, 'YYYY-MM-DD')                    AS data_falecimento,
        {{ clean_string('ufnascimento', 'upper') }}               AS uf_nascimento,
        {{ clean_string('municipionascimento', 'upper') }}         AS uf_municipio_nascimento,
        {{ clean_string('escolaridade', 'upper') }}               AS escolaridade,
        COALESCE(ultimostatus_email, ultimostatus_gabinete_email) AS email,
        loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM source
)

SELECT * FROM renamed
