{{ config(
    tags=["camara", "parlamentar"]
) }}

WITH source AS (
    SELECT * FROM {{ source('camara','raw_camara_deputados') }}
),

renamed AS (
    SELECT
        id AS deputado_id_nk,
        nomecivil as nome_civil,
        ultimostatus_nomeeleitoral as nome_eleitoral,
        sexo,
        redesocial as rede_social,
        datanascimento as data_nascimento,
        datafalecimento as data_falecimento,
        ufnascimento as uf_nascimento,
        municipionascimento as uf_municipio_nascimento,
        escolaridade,
        COALESCE(ultimostatus_email::TEXT, ultimostatus_gabinete_email::TEXT) AS email
    FROM source
)

SELECT * FROM renamed
