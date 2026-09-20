{{
  config(
    tags = ['financas', 'marts'],
  )
}}

{#- Outro patrimônio que o de `patrimonio`: nunca somar os dois. É mart, e não
    intermediate, porque as extrações dos relatórios só leem marts. -#}

WITH
datas AS (
    SELECT DISTINCT
        month_start_date,
        month_end_date,
        quarter_of_year,
        year_number
    FROM {{ ref('dim_datas') }}
),

ativos AS (
    SELECT
        t1.mes_base,
        t2.month_end_date  AS mes_final,
        t2.quarter_of_year AS trimestre,
        t2.year_number     AS ano,
        t1.mes_base = MAX(t1.mes_base) OVER () AS fl_mes_atual,
        t1.total_patrimonio_liquido,
        t1.saldo_banco_brasil_deusa,
        t1.saldo_banco_brasil_investimentos_deusa,
        t1.saldo_bradesco_deusa,
        t1.saldo_bradesco_investimentos_deusa,
        t1.saldo_nubank_deusa,
        t1.saldo_nubank_investimentos_deusa,
        t1.saldo_nubank_cashback_deusa
    FROM {{ ref('stg_patrimonio_deusa') }} AS t1
    INNER JOIN datas AS t2
        ON t1.mes_base = t2.month_start_date
)

SELECT
    ativos.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM ativos
ORDER BY mes_base
