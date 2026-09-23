{% snapshot snap_radarcongresso_parlamentares %}

{{
    config(
        strategy='check',
        unique_key=['idparlamentarvoz','idparlamentar'],
        check_cols=[
            'nomeeleitoral',
            'uf',
            'ultima_legislatura',
            'emexercicio',
            'casa',
            'parlamentarpartido',
            'nomeprocessado'
            ],
        hard_deletes='new_record'
    )
}}

WITH
source AS (
    SELECT
        idparlamentarvoz,
        idparlamentar,
        nomeeleitoral,
        uf,
        ultima_legislatura,
        emexercicio,
        casa,
        parlamentarpartido,
        nomeprocessado
    FROM {{ source('radar','raw_radar_parlamentares') }}
)
SELECT * FROM source

{% endsnapshot %}