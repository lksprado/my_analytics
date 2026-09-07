{{
  config(
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

{#-
  Patrimônio de Deusa mês a mês, da planilha dela. Mesmo shape de `patrimonio`,
  mas OUTRO patrimônio: outra planilha, outra carteira, outros objetivos. Os dois
  aparecem lado a lado em `riqueza` porque enfrentam o mesmo benchmark, e NUNCA
  devem ser somados.

  Ao contrário do casal, a planilha dela não abre patrimônio líquido por titular
  — só o total, mais os saldos por conta. Por isso ela não entra em `patrimonio`
  e a variação MoM dela é calculada dentro de `riqueza`, sem um patrimonio_mom
  próprio para reaproveitar.

  Existe como mart, e não como modelo intermediário, porque a extração do
  relatório de meio de mês precisa do total líquido da planilha para imprimir a
  reconciliação contra marts.carteira_deusa — e as extrações dos relatórios leem
  exclusivamente a camada marts.
-#}

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
    CURRENT_TIMESTAMP AS model_updated_at
FROM ativos
ORDER BY mes_base
