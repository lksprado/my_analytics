{{ config(
    tags=["stg","radar","senado"]
) }}


WITH source AS (
    SELECT *
    FROM {{ ref('snap_radarcongresso_governismo_senadores') }}
),

-- afavor, n e total são o acumulado do mandato repetido em todas as linhas trimestrais do
-- parlamentar: n é o denominador, não os votos contra, e ROUND(100 * afavor / n) = total.
renamed AS (
    SELECT
        id::INT                             AS radar_parlamentar_id_nk,
        afavor::INT                         AS qt_votos_alinhados_legislatura,
        n::INT                              AS qt_votos_legislatura,
        total::INT                          AS perc_governismo_legislatura,
        perc_governismo::INT                AS perc_governismo_trimestre,
        TO_DATE(trimestre, 'YYYY-MM-DD')    AS data_trimestre,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM source
    WHERE dbt_valid_to IS NULL
)

SELECT * FROM renamed
