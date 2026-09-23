{{ config(
    tags=["politica"]
) }}

WITH
governismo_radar AS (
    SELECT
        'CAMARA' AS casa,
        radar_parlamentar_id_nk,
        qt_votos_alinhados_legislatura,
        qt_votos_legislatura,
        perc_governismo_legislatura,
        data_trimestre
    FROM {{ ref('stg_radarcongresso_governismo_deputados') }}
    UNION ALL
    SELECT
        'SENADO' AS casa,
        radar_parlamentar_id_nk,
        qt_votos_alinhados_legislatura,
        qt_votos_legislatura,
        perc_governismo_legislatura,
        data_trimestre
    FROM {{ ref('stg_radarcongresso_governismo_senadores') }}
),

-- O acumulado do mandato se repete em todas as linhas trimestrais do parlamentar.
acumulado AS (
    SELECT
        casa,
        radar_parlamentar_id_nk,
        qt_votos_alinhados_legislatura,
        qt_votos_legislatura,
        perc_governismo_legislatura,
        MAX(data_trimestre) AS data_referencia
    FROM governismo_radar
    GROUP BY
        casa,
        radar_parlamentar_id_nk,
        qt_votos_alinhados_legislatura,
        qt_votos_legislatura,
        perc_governismo_legislatura
),

parlamentares AS (
    SELECT
        sk_parlamentar,
        casa,
        COALESCE(radar_deputado_id_fk, radar_senador_id_fk) AS radar_parlamentar_id_fk
    FROM {{ ref('dim_parlamentares') }}
    WHERE COALESCE(radar_deputado_id_fk, radar_senador_id_fk) IS NOT NULL
),

final AS (
    SELECT
        COALESCE(p.sk_parlamentar, '{{ var("null_key") }}') AS sk_parlamentar,
        a.casa,
        a.radar_parlamentar_id_nk,
        c.legislatura,
        a.qt_votos_alinhados_legislatura,
        a.qt_votos_legislatura,
        a.perc_governismo_legislatura,
        '{{ run_started_at }}'::TIMESTAMPTZ                 AS model_run_at
    FROM acumulado AS a
    LEFT JOIN parlamentares AS p
        ON a.casa = p.casa AND a.radar_parlamentar_id_nk = p.radar_parlamentar_id_fk
    LEFT JOIN {{ ref('dim_calendario_legislativo') }} AS c
        ON a.data_referencia - 1 = c.data
)

SELECT * FROM final
