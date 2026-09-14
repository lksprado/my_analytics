{{ config(
    tags=["camara", "parlamentar"]
) }}

WITH source AS (
    SELECT * FROM {{ source('camara','raw_camara_deputados') }}
),

renamed AS (
    SELECT
        id::BIGINT                                                            AS deputado_id_nk,
        nomecivil                                                             AS nome_civil,
        ultimostatus_nomeeleitoral                                            AS nome_eleitoral,
        sexo,
        redesocial                                                            AS rede_social,
        datanascimento                                                        AS data_nascimento,
        datafalecimento                                                       AS data_falecimento,
        ufnascimento                                                          AS uf_nascimento,
        municipionascimento                                                   AS uf_municipio_nascimento,
        escolaridade,
        COALESCE(ultimostatus_email::TEXT, ultimostatus_gabinete_email::TEXT) AS email
    FROM source
)

SELECT * FROM renamed
