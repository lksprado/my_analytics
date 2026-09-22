{{ config(
    tags=["camara", "senado", "radar", "votacoes"]
) }}

WITH
governismo AS (
    SELECT
        *,
        'CAMARA' AS casa
    FROM {{ ref('stg_radarcongresso_governismo_deputados') }}
    UNION ALL
    SELECT
        *,
        'SENADO' AS casa
    FROM {{ ref('stg_radarcongresso_governismo_senadores') }}
),

depara AS (
    SELECT
        id_parlamentar_radar,
        id_parlamentar_congresso,
        nome_eleitoral,
        uf
    FROM {{ ref('stg_radarcongresso_parlamentares') }}
),

final AS (
    SELECT
        t1.casa,
        t2.id_parlamentar_congresso
            AS parlamentar_id_nk,
        t1.id_parlamentar_radar,
        t2.nome_eleitoral,
        t2.uf,
        -- data_trimestre é o dia seguinte ao fim do trimestre medido (2023-07-01 é o segundo de
        -- 2023), com a exceção do primeiro, que vem como 2023-03-31. Recuar um dia acerta os doze.
        EXTRACT(YEAR FROM t1.data_trimestre - INTERVAL '1 day')::INT
            AS ano,
        EXTRACT(QUARTER FROM t1.data_trimestre - INTERVAL '1 day')::INT
            AS trimestre,
        t1.data_trimestre,
        t1.perc_governismo_trimestre,
        t1.qt_votos_legislatura,
        t1.qt_votos_alinhados_legislatura,
        t1.perc_governismo_legislatura,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM governismo AS t1
    INNER JOIN depara AS t2
        ON t1.id_parlamentar_radar = t2.id_parlamentar_radar
)

SELECT * FROM final
