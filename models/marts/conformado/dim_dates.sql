{{ config(
    tags=["datas"]
) }}

{#- Espelho de dim_datas em inglês: calendário puro sem datas especiais da família.
    Não expõe dados pessoais, seguro para publicação em domínios públicos. -#}

WITH
date_dimension AS (
    SELECT * FROM {{ ref("int_dates") }}
),

holiday_translation AS (
    SELECT
        'CONFRATERNIZACAO UNIVERSAL' AS nome_feriado_pt,
        'NEW YEAR''S DAY'            AS holiday_name_en,
        'NATIONAL'                   AS holiday_type_en
    UNION ALL
    SELECT
        'TIRADENTES',
        'TIRADENTES DAY',
        'NATIONAL'
    UNION ALL
    SELECT
        'DIA DO TRABALHO',
        'LABOR DAY',
        'NATIONAL'
    UNION ALL
    SELECT
        'INDEPENDENCIA DO BRASIL',
        'BRAZILIAN INDEPENDENCE DAY',
        'NATIONAL'
    UNION ALL
    SELECT
        'NOSSA SENHORA APARECIDA',
        'OUR LADY OF APARECIDA',
        'NATIONAL'
    UNION ALL
    SELECT
        'FINADOS',
        'ALL SOULS'' DAY',
        'NATIONAL'
    UNION ALL
    SELECT
        'PROCLAMACAO DA REPUBLICA',
        'REPUBLIC PROCLAMATION DAY',
        'NATIONAL'
    UNION ALL
    SELECT
        'DIA NACIONAL DE ZUMBI E DA CONSCIENCIA NEGRA',
        'NATIONAL DAY OF ZUMBI AND BLACK AWARENESS',
        'NATIONAL'
    UNION ALL
    SELECT
        'NATAL',
        'CHRISTMAS',
        'NATIONAL'
    UNION ALL
    SELECT
        'CARNAVAL',
        'CARNIVAL',
        'OPTIONAL HOLIDAY'
    UNION ALL
    SELECT
        'SEXTA-FEIRA SANTA',
        'GOOD FRIDAY',
        'NATIONAL'
    UNION ALL
    SELECT
        'CORPUS CHRISTI',
        'CORPUS CHRISTI',
        'OPTIONAL HOLIDAY'
    UNION ALL
    SELECT
        'SEXTA-FEIRA SANTA / TIRADENTES',
        'GOOD FRIDAY / TIRADENTES DAY',
        'NATIONAL'
),

final AS (
    SELECT
        d.data_sk                                        AS date_sk,
        d.date_day,
        d.prior_date_day,
        d.next_date_day,
        d.prior_year_date_day,
        d.prior_year_over_year_date_day,
        d.day_of_week,
        d.day_of_week_name,
        d.day_of_week_name_short,
        d.day_of_month,
        d.day_of_year,
        d.week_start_date,
        d.week_end_date,
        d.prior_year_week_start_date,
        d.prior_year_week_end_date,
        d.week_of_year,
        d.iso_week_start_date,
        d.iso_week_end_date,
        d.prior_year_iso_week_start_date,
        d.prior_year_iso_week_end_date,
        d.iso_week_of_year,
        d.prior_year_week_of_year,
        d.prior_year_iso_week_of_year,
        d.month_of_year,
        d.month_name,
        d.month_name_short,
        d.month_start_date,
        d.month_end_date,
        d.prior_year_month_start_date,
        d.prior_year_month_end_date,
        d.quarter_of_year,
        d.quarter_start_date,
        d.quarter_end_date,
        d.year_number,
        d.year_start_date,
        d.year_end_date,
        d.mes_sk                                         AS month_sk,
        CASE WHEN d.month_of_year <= 6 THEN 1 ELSE 2 END AS half_of_year,
        d.fl_fim_de_semana                               AS is_weekend,
        d.fl_feriado                                     AS is_holiday,
        COALESCE(t.holiday_name_en, d.nome_feriado)      AS holiday_name,
        COALESCE(
            t.holiday_type_en,
            CASE WHEN d.tipo_feriado = 'NACIONAL' THEN 'NATIONAL'
                ELSE 'OPTIONAL HOLIDAY'
            END
        )                                    AS holiday_type,
        d.fl_dia_util                                    AS is_business_day,
        d.dia_util_mes                                   AS business_day_of_month,
        '{{ run_started_at }}'::TIMESTAMPTZ              AS model_run_at
    FROM date_dimension AS d
    LEFT JOIN holiday_translation AS t
        ON d.nome_feriado = t.nome_feriado_pt
)

SELECT * FROM final
ORDER BY date_sk
