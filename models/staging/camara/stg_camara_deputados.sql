{{ config(
    tags=["camara", "parlamentar"]
) }}

WITH snap AS (
    SELECT * FROM {{ ref('snap_camara_deputados') }}
),

renamed AS (
    SELECT
        deputado_id_nk,
        nome_civil,
        nome_eleitoral,
        sexo,
        rede_social,
        data_nascimento,
        data_falecimento,
        uf_nascimento,
        uf_municipio_nascimento,
        escolaridade,
        email,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM snap
    WHERE dbt_valid_to IS NULL
)

SELECT * FROM renamed
