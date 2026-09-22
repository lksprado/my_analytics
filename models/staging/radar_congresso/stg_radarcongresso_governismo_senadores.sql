{{ config(
    tags=["stg","radar","senado"]
) }}


WITH source AS (
    SELECT *
    FROM {{ source('radar','raw_radar_governismo_senadores') }}
),

-- afavor, n e total são o acumulado do mandato repetido em todas as linhas trimestrais do
-- parlamentar: n é o denominador, não os votos contra, e ROUND(100 * afavor / n) = total.
renamed AS (
    SELECT
        id::INT                             AS id_parlamentar_radar,
        afavor::INT                         AS qt_votos_alinhados_legislatura,
        n::INT                              AS qt_votos_legislatura,
        total::INT                          AS perc_governismo_legislatura,
        TO_DATE(trimestre, 'YYYY-MM-DD')    AS data_trimestre,
        perc_governismo::INT                AS perc_governismo_trimestre,
        loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM source
)

SELECT * FROM renamed
