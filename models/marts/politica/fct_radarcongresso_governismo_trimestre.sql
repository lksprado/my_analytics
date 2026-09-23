{{ config(
    tags=["politica"]
) }}

WITH
governismo_radar AS (
    SELECT
        'CAMARA' AS casa,
        radar_parlamentar_id_nk,
        perc_governismo_trimestre,
        data_trimestre
    FROM {{ ref('stg_radarcongresso_governismo_deputados') }}
    UNION ALL
    SELECT
        'SENADO' AS casa,
        radar_parlamentar_id_nk,
        perc_governismo_trimestre,
        data_trimestre
    FROM {{ ref('stg_radarcongresso_governismo_senadores') }}
),

parlamentares AS (
    SELECT
        sk_parlamentar,
        casa,
        COALESCE(radar_deputado_id_fk, radar_senador_id_fk) AS radar_parlamentar_id_fk
    FROM {{ ref('dim_parlamentares') }}
    WHERE COALESCE(radar_deputado_id_fk, radar_senador_id_fk) IS NOT NULL
),

calendario AS (
    SELECT
        data,
        legislatura,
        ano,
        trimestre_do_ano
    FROM {{ ref('dim_calendario_legislativo') }}
),

final AS (
    SELECT
        COALESCE(p.sk_parlamentar, '{{ var("null_key") }}') AS sk_parlamentar,
        r.casa,
        r.radar_parlamentar_id_nk,
        c.legislatura,
        c.ano,
        c.trimestre_do_ano                                  AS trimestre,
        r.data_trimestre,
        r.perc_governismo_trimestre,
        '{{ run_started_at }}'::TIMESTAMPTZ                 AS model_run_at
    FROM governismo_radar AS r
    LEFT JOIN parlamentares AS p
        ON r.casa = p.casa AND r.radar_parlamentar_id_nk = p.radar_parlamentar_id_fk
    -- O Radar marca o trimestre pelo dia seguinte ao fim; o primeiro vem como 2023-03-31.
    LEFT JOIN calendario AS c
        ON r.data_trimestre - 1 = c.data
    WHERE r.perc_governismo_trimestre IS NOT NULL
)

SELECT * FROM final
