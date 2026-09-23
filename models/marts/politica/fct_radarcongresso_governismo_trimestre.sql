{{ config(
    tags=["politica"]
) }}

WITH
governismo_radar AS (
    SELECT
        'CAMARA'                        AS casa,
        radar_parlamentar_id_nk,
        perc_governismo_trimestre,
        data_trimestre
    FROM {{ ref('stg_radarcongresso_governismo_deputados') }}
    UNION ALL
    SELECT
        'SENADO'                        AS casa,
        radar_parlamentar_id_nk,
        perc_governismo_trimestre,
        data_trimestre
    FROM {{ ref('stg_radarcongresso_governismo_senadores') }}
)

SELECT
    t1.casa,
    t1.radar_parlamentar_id_nk,
    CASE WHEN t1.casa = 'CAMARA' THEN t2.deputado_id_nk ELSE 0 END AS deputado_id_fk,
    CASE WHEN t1.casa = 'SENADO' THEN t3.senador_id_nk ELSE 0 END  AS senador_id_fk,        
    t1.perc_governismo_trimestre,
    t1.data_trimestre,
    '{{ run_started_at }}'::TIMESTAMPTZ                            AS model_run_at
FROM governismo_radar t1
    LEFT JOIN {{ ref('dim_parlamentares') }} t2
        ON t1.radar_parlamentar_id_nk = t2.radar_deputado_id_fk
        AND t1.casa = 'CAMARA'
    LEFT JOIN {{ ref('dim_parlamentares') }} t3
        ON t1.radar_parlamentar_id_nk = t3.radar_senador_id_fk
        AND t1.casa = 'SENADO'
WHERE t1.perc_governismo_trimestre IS NOT NULL