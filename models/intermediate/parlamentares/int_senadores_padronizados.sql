{{ config(
    tags=["senado", "parlamentar"]
) }}

WITH
senadores AS (
    SELECT DISTINCT ON (senador_id_nk)
        1                                                AS prioridade,
        senador_id_nk                                    AS parlamentar_id_nk,
        nome,
        nome_completo,
        sexo,
        uf
    FROM {{ ref('stg_senado_senadores') }}
    ORDER BY senador_id_nk
),

senadores_historico AS (
    SELECT DISTINCT ON (senador_id_nk)
        0                                                AS prioridade,
        senador_id_nk                                    AS parlamentar_id_nk,
        nome,
        nome_completo,
        sexo,
        uf
    FROM {{ ref('stg_senado_legislaturas') }}
    ORDER BY senador_id_nk
),

senadores_completo AS (
    SELECT
        *,
        'SENADO'                                                     AS casa,
        ROW_NUMBER() OVER (PARTITION BY parlamentar_id_nk ORDER BY prioridade DESC) AS rn
    FROM (
        SELECT * FROM senadores
        UNION ALL
        SELECT * FROM senadores_historico
        ORDER BY parlamentar_id_nk
    )
),

senadores_radar AS (
    SELECT 
        radar_parlamentar_id_nk,
        parlamentar_id_fk,
        uf
    FROM {{ ref('stg_radarcongresso_parlamentares') }}
    WHERE casa = 'SENADO'
),

final AS (
    SELECT
        t1.casa,
        t1.parlamentar_id_nk,
        t2.radar_parlamentar_id_nk AS radar_parlamentar_id_fk,
        t1.nome,
        t1.nome_completo,
        t1.sexo,
        COALESCE(t1.uf, t2.uf)     AS uf,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM senadores_completo t1
    LEFT JOIN senadores_radar AS t2 
        ON t1.parlamentar_id_nk = t2.parlamentar_id_fk
    WHERE rn = 1
)

SELECT * FROM final
