{{ config(
    tags=["politica"]
) }}

WITH
versoes AS (
    SELECT
        *,
        'CAMARA' AS casa
    FROM {{ ref('snap_radarcongresso_governismo_deputados') }}
    UNION ALL
    SELECT
        *,
        'SENADO' AS casa
    FROM {{ ref('snap_radarcongresso_governismo_senadores') }}
),

limpas AS (
    SELECT
        casa,
        id                                   AS parlamentar_fonte_id_nk,
        afavor::INT                          AS qt_alinhados,
        n::INT                               AS qt_base,
        total::NUMERIC                       AS governismo_mandato,
        perc_governismo::NUMERIC             AS governismo_trimestre,
        -- O Radar marca o trimestre pelo dia seguinte ao fim; o primeiro vem como 2023-03-31.
        TO_DATE(trimestre, 'YYYY-MM-DD') - 1 AS data_referencia,
        dbt_valid_from::DATE                 AS data_coleta,
        dbt_valid_to::DATE                   AS data_fim_vigencia
    FROM versoes
    WHERE COALESCE(dbt_is_deleted, 'False') <> 'True'
),

trimestral AS (
    SELECT
        casa,
        parlamentar_fonte_id_nk,
        'GOVERNISMO TRIMESTRAL'                                                  AS indicador,
        'TRIMESTRE'                                                              AS periodo_tipo,
        DATE_TRUNC('quarter', data_referencia)::DATE                             AS periodo_inicio,
        (DATE_TRUNC('quarter', data_referencia) + INTERVAL '3 months')::DATE - 1 AS periodo_fim,
        governismo_trimestre                                                     AS valor_original,
        NULL::INT                                                                AS qt_base,
        data_coleta,
        data_fim_vigencia
    FROM limpas
    WHERE governismo_trimestre IS NOT NULL
),

-- O acumulado do mandato se repete em todas as linhas trimestrais da mesma coleta.
mandato AS (
    SELECT
        l.casa,
        l.parlamentar_fonte_id_nk,
        'GOVERNISMO NO MANDATO'  AS indicador,
        'MANDATO'                AS periodo_tipo,
        MIN(s.inicio::DATE)      AS periodo_inicio,
        MAX(l.data_referencia)   AS periodo_fim,
        l.governismo_mandato     AS valor_original,
        l.qt_base,
        l.data_coleta,
        MIN(l.data_fim_vigencia) AS data_fim_vigencia
    FROM limpas AS l
    LEFT JOIN {{ ref('seed_legislaturas') }} AS s
        ON l.data_referencia BETWEEN s.inicio::DATE AND s.fim::DATE
    WHERE l.governismo_mandato IS NOT NULL
    GROUP BY l.casa, l.parlamentar_fonte_id_nk, l.governismo_mandato, l.qt_base, l.data_coleta
),

final AS (
    SELECT
        'RADAR CONGRESSO'                   AS fonte,
        casa,
        parlamentar_fonte_id_nk,
        indicador,
        periodo_tipo,
        periodo_inicio,
        periodo_fim,
        valor_original,
        qt_base,
        data_coleta,
        data_fim_vigencia,
        NULL::INT                           AS parlamentar_casa_id,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM trimestral
    UNION ALL
    SELECT
        'RADAR CONGRESSO'                   AS fonte,
        casa,
        parlamentar_fonte_id_nk,
        indicador,
        periodo_tipo,
        periodo_inicio,
        periodo_fim,
        valor_original,
        qt_base,
        data_coleta,
        data_fim_vigencia,
        NULL::INT                           AS parlamentar_casa_id,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM mandato
)

SELECT * FROM final
