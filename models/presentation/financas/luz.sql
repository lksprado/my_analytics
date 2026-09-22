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

luz AS (
    SELECT
        t1.mes,
        t2.trimestre_do_ano AS trimestre,
        t2.ano,
        t1.vlr_fatura,
        t1.kwh,
        t1.dias,
        t1.kwh_dia,
        t1.preco_kwh
    FROM {{ ref('stg_luz') }} AS t1
    INNER JOIN datas AS t2
        ON t1.mes = t2.inicio_mes
)

SELECT
    luz.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM luz
ORDER BY luz.mes
