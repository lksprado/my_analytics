{% snapshot snap_radarcongresso_governismo_senadores %}

{{
    config(
        strategy='check',
        unique_key=['id', 'trimestre'],
        check_cols=[
            'afavor',
            'n',
            'total',
            'perc_governismo'
            ],
        hard_deletes='new_record'
    )
}}

WITH
source AS (
    SELECT
        id,
        afavor,
        n,
        total,
        trimestre,
        perc_governismo
    FROM {{ source('radar','raw_radar_governismo_senadores') }}
)
SELECT * FROM source

{% endsnapshot %}