{{ config(
    tags=["datas"]
) }}

{#- Contém datas da família: não expor fl_data_especial/motivo em domínios publicáveis. -#}

WITH
date_dimension AS (
    SELECT * FROM {{ ref("int_dates") }}
),

datas_especiais AS (
    SELECT * FROM {{ ref('stg_datas_especiais') }}
),

final AS (
    SELECT
        d.*,
        d.date_day                                        AS data,
        d.prior_date_day                                  AS data_anterior,
        d.next_date_day                                   AS proxima_data,
        d.prior_year_date_day                             AS data_ano_anterior,
        d.prior_year_over_year_date_day                   AS data_mesma_semana_ano_anterior,
        d.day_of_week                                     AS dia_semana_num,
        d.day_of_month                                    AS dia_do_mes,
        d.day_of_year                                     AS dia_do_ano,
        d.week_start_date                                 AS inicio_semana,
        d.week_end_date                                   AS fim_semana,
        d.prior_year_week_start_date                      AS inicio_semana_ano_anterior,
        d.prior_year_week_end_date                        AS fim_semana_ano_anterior,
        d.week_of_year                                    AS semana_do_ano,
        d.iso_week_start_date                             AS inicio_semana_iso,
        d.iso_week_end_date                               AS fim_semana_iso,
        d.prior_year_iso_week_start_date                  AS inicio_semana_iso_ano_anterior,
        d.prior_year_iso_week_end_date                    AS fim_semana_iso_ano_anterior,
        d.iso_week_of_year                                AS semana_iso_do_ano,
        d.prior_year_week_of_year                         AS semana_do_ano_ano_anterior,
        d.prior_year_iso_week_of_year                     AS semana_iso_do_ano_ano_anterior,
        d.month_of_year                                   AS mes_do_ano,
        d.month_start_date                                AS inicio_mes,
        d.month_end_date                                  AS fim_mes,
        d.prior_year_month_start_date                     AS inicio_mes_ano_anterior,
        d.prior_year_month_end_date                       AS fim_mes_ano_anterior,
        d.quarter_of_year                                 AS trimestre_do_ano,
        d.quarter_start_date                              AS inicio_trimestre,
        d.quarter_end_date                                AS fim_trimestre,
        d.year_number                                     AS ano,
        d.year_start_date                                 AS inicio_ano,
        d.year_end_date                                   AS fim_ano,
        CASE
            WHEN EXISTS (
                    SELECT 1
                    FROM datas_especiais                  AS me
                    WHERE me.mes_num = d.month_of_year
                        AND d.year_number >= COALESCE(me.ano_inicio, d.year_number)
                ) THEN 1
            ELSE 0
        END                                               AS fl_mes_especial,
        CASE WHEN de.motivo IS NOT NULL THEN 1 ELSE 0 END AS fl_data_especial,
        COALESCE(de.motivo, 'NORMAL')                     AS motivo
    FROM date_dimension AS d
    LEFT JOIN datas_especiais AS de
        ON d.month_of_year = de.mes_num
        AND d.day_of_month = de.dia
        AND d.year_number >= COALESCE(de.ano_inicio, d.year_number)
)

SELECT * FROM final
ORDER BY data_sk
