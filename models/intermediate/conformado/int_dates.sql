{{ config(
    tags=["datas"]
) }}

{#- Espinha larga de propósito: os consumidores fazem INNER JOIN a partir do
    próprio dado, e uma espinha mais curta que ele descarta linhas sem aviso.
    O fim do get_date_dimension é exclusivo, por isso o dia seguinte ao último.
    Feriados seguem o calendário bancário nacional (ANBIMA/B3), com Carnaval e
    Corpus Christi; antes de ~1950 é a regra atual aplicada para trás. -#}

WITH
base AS (
    {{ dbt_date.get_date_dimension("1900-01-01", "2101-01-01") }}
),

anos AS (
    SELECT DISTINCT year_number AS ano FROM base
),

{#- Páscoa pelo algoritmo anônimo gregoriano (Meeus/Jones/Butcher); depende
    da divisão de integer truncar. -#}
pascoa_passos AS (
    SELECT
        ano,
        ano % 19                AS a,
        ano / 100               AS b,
        ano % 100               AS c
    FROM anos
),

pascoa_passos_2 AS (
    SELECT
        ano, a, b, c,
        (19 * a + b - b / 4 - (b - (b + 8) / 25 + 1) / 3 + 15) % 30  AS h,
        c / 4                                                       AS i,
        c % 4                                                       AS k,
        b % 4                                                       AS e
    FROM pascoa_passos
),

pascoa_passos_3 AS (
    SELECT
        ano, a, h,
        (32 + 2 * e + 2 * i - h - k) % 7  AS l
    FROM pascoa_passos_2
),

pascoa AS (
    SELECT
        ano,
        MAKE_DATE(
            ano,
            (h + l - 7 * ((a + 11 * h + 22 * l) / 451) + 114) / 31,
            (h + l - 7 * ((a + 11 * h + 22 * l) / 451) + 114) % 31 + 1
        ) AS domingo_pascoa
    FROM pascoa_passos_3
),

feriados_fixos (dia, mes, ano_inicio, nome_feriado, tipo_feriado) AS (
    VALUES
        (1,  1,  NULL, 'CONFRATERNIZACAO UNIVERSAL',      'NACIONAL'),
        (21, 4,  NULL, 'TIRADENTES',                      'NACIONAL'),
        (1,  5,  NULL, 'DIA DO TRABALHO',                 'NACIONAL'),
        (7,  9,  NULL, 'INDEPENDENCIA DO BRASIL',         'NACIONAL'),
        (12, 10, 1980, 'NOSSA SENHORA APARECIDA',         'NACIONAL'),
        (2,  11, NULL, 'FINADOS',                         'NACIONAL'),
        (15, 11, NULL, 'PROCLAMACAO DA REPUBLICA',        'NACIONAL'),
        (20, 11, 2024, 'DIA NACIONAL DE ZUMBI E DA CONSCIENCIA NEGRA', 'NACIONAL'),
        (25, 12, NULL, 'NATAL',                           'NACIONAL')
),

feriados AS (
    SELECT
        MAKE_DATE(a.ano, f.mes, f.dia)  AS data_feriado,
        f.nome_feriado,
        f.tipo_feriado
    FROM anos AS a
    INNER JOIN feriados_fixos AS f
        ON a.ano >= COALESCE(f.ano_inicio, a.ano)

    UNION ALL

    SELECT domingo_pascoa - 48, 'CARNAVAL',            'PONTO FACULTATIVO' FROM pascoa
    UNION ALL
    SELECT domingo_pascoa - 47, 'CARNAVAL',            'PONTO FACULTATIVO' FROM pascoa
    UNION ALL
    SELECT domingo_pascoa - 2,  'SEXTA-FEIRA SANTA',   'NACIONAL'          FROM pascoa
    UNION ALL
    SELECT domingo_pascoa + 60, 'CORPUS CHRISTI',      'PONTO FACULTATIVO' FROM pascoa
),

{#- Fixo e móvel podem cair no mesmo dia (21/04/2000). -#}
feriados_por_dia AS (
    SELECT
        data_feriado,
        STRING_AGG(nome_feriado, ' / ' ORDER BY nome_feriado)  AS nome_feriado,
        CASE
            WHEN BOOL_OR(tipo_feriado = 'NACIONAL') THEN 'NACIONAL'
            ELSE 'PONTO FACULTATIVO'
        END                                                    AS tipo_feriado
    FROM feriados
    GROUP BY data_feriado
),

calendario AS (
    SELECT
        CAST(TO_CHAR(b.date_day, 'YYYYMMDD') AS INTEGER)       AS data_sk,
        b.date_day,
        b.prior_date_day,
        b.next_date_day,
        b.prior_year_date_day,
        b.prior_year_over_year_date_day,
        b.day_of_week,
        b.day_of_week_name,
        b.day_of_week_name_short,
        {#- dbt_date devolve double precision. -#}
        b.day_of_month::INT                                    AS day_of_month,
        b.day_of_year::INT                                     AS day_of_year,
        b.week_start_date,
        b.week_end_date,
        b.prior_year_week_start_date,
        b.prior_year_week_end_date,
        b.week_of_year,
        b.iso_week_start_date,
        b.iso_week_end_date,
        b.prior_year_iso_week_start_date,
        b.prior_year_iso_week_end_date,
        b.iso_week_of_year,
        b.prior_year_week_of_year,
        b.prior_year_iso_week_of_year,
        b.month_of_year,
        b.month_name,
        b.month_name_short,
        b.month_start_date,
        b.month_end_date,
        b.prior_year_month_start_date,
        b.prior_year_month_end_date,
        b.quarter_of_year,
        b.quarter_start_date,
        b.quarter_end_date,
        b.year_number,
        b.year_start_date,
        b.year_end_date,

        CAST(TO_CHAR(b.date_day, 'YYYYMM') AS INTEGER)         AS mes_sk,
        CASE WHEN b.month_of_year <= 6 THEN 1 ELSE 2 END       AS semestre,
        (ARRAY[
            'SEGUNDA-FEIRA', 'TERCA-FEIRA', 'QUARTA-FEIRA', 'QUINTA-FEIRA',
            'SEXTA-FEIRA', 'SABADO', 'DOMINGO'
        ])[b.day_of_week]                                      AS nome_dia_semana,
        (ARRAY['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB', 'DOM'])[b.day_of_week]
                                                               AS nome_dia_semana_abrev,
        (ARRAY[
            'JANEIRO', 'FEVEREIRO', 'MARCO', 'ABRIL', 'MAIO', 'JUNHO',
            'JULHO', 'AGOSTO', 'SETEMBRO', 'OUTUBRO', 'NOVEMBRO', 'DEZEMBRO'
        ])[b.month_of_year]                                    AS nome_mes,
        (ARRAY[
            'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
            'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'
        ])[b.month_of_year]                                    AS nome_mes_abrev,

        b.day_of_week IN (6, 7)                                AS fl_fim_de_semana,
        f.data_feriado IS NOT NULL                             AS fl_feriado,
        f.nome_feriado,
        f.tipo_feriado,
        b.day_of_week NOT IN (6, 7) AND f.data_feriado IS NULL AS fl_dia_util
    FROM base AS b
    LEFT JOIN feriados_por_dia AS f
        ON b.date_day = f.data_feriado
)

SELECT
    *,
    CASE
        WHEN fl_dia_util
            THEN COUNT(*) FILTER (WHERE fl_dia_util) OVER (
                PARTITION BY month_start_date ORDER BY date_day
            )::INT
    END AS dia_util_mes
FROM calendario
