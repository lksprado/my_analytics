{% snapshot snap_camara_deputados %}

{{
    config(
        strategy='check',
        unique_key=['deputado_id_nk'],
        check_cols=[
            'nome_civil,',
            'nome_eleitoral,',
            'sexo,',
            'rede_social,',
            'data_nascimento,',
            'data_falecimento,',
            'uf_nascimento,',
            'uf_municipio_nascimento,',
            'escolaridade,',
            'email'
            ],
        hard_deletes='new_record'
    )
}}

WITH
source AS (
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
        email
    FROM {{ ref('eph_camara_deputados') }}
)
SELECT * FROM source

{% endsnapshot %}