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
        inicio_mes,
        fim_mes,
        trimestre_do_ano,
        ano
    FROM {{ ref('dim_datas') }}
),

ativos AS (
    SELECT
        t1.mes_base,
        t2.fim_mes                             AS mes_final,
        t2.trimestre_do_ano                    AS trimestre,
        t2.ano,
        t1.total_patrimonio_liquido,
        t1.saldo_banco_brasil_deusa,
        t1.saldo_banco_brasil_investimentos_deusa,
        t1.saldo_bradesco_deusa,
        t1.saldo_bradesco_investimentos_deusa,
        t1.saldo_nubank_deusa,
        t1.saldo_nubank_investimentos_deusa,
        t1.saldo_nubank_cashback_deusa,
        t1.mes_base = MAX(t1.mes_base) OVER () AS fl_mes_atual
    FROM {{ ref('stg_patrimonio_deusa') }} AS t1
    INNER JOIN datas AS t2
        ON t1.mes_base = t2.inicio_mes
)

SELECT
    ativos.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM ativos
ORDER BY ativos.mes_base
