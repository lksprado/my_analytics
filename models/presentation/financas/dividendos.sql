{{
  config(
    tags = ['financas', 'marts'],
  )
}}


WITH
datas AS (
    SELECT DISTINCT
        inicio_mes,
        trimestre_do_ano,
        ano
    FROM {{ ref('dim_datas') }}
),

pessoas AS (
    SELECT DISTINCT pessoa
    FROM {{ ref('int_dividendos') }}
),

dividendos AS (
    SELECT
        mes_base,
        pessoa,
        SUM(vlr_liquido_brl) AS vlr_liquido_brl
    FROM {{ ref('int_dividendos') }}
    GROUP BY 1, 2
),

periodo AS (
    SELECT
        MIN(mes_base) AS data_min,
        MAX(mes_base) AS data_max
    FROM dividendos
),

spine AS (
    SELECT
        datas.inicio_mes,
        datas.trimestre_do_ano,
        datas.ano,
        pessoas.pessoa
    FROM datas
    CROSS JOIN pessoas
    CROSS JOIN periodo
    WHERE datas.inicio_mes BETWEEN periodo.data_min AND periodo.data_max
),

final AS (
    SELECT
        spine.inicio_mes                        AS mes_base,
        spine.ano,
        spine.trimestre_do_ano                  AS trimestre,
        spine.pessoa,
        COALESCE(dividendos.vlr_liquido_brl, 0) AS vlr_liquido_brl
    FROM spine
    LEFT JOIN dividendos
        ON spine.inicio_mes = dividendos.mes_base
        AND spine.pessoa = dividendos.pessoa
    ORDER BY spine.inicio_mes
)

SELECT
    final.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM final
