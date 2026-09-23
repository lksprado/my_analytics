{{
  config(
    tags = ['financas', 'marts'],
  )
}}

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
        t1.total_patrimonio_bruto,
        t1.total_patrimonio_liquido,
        t1.patrimonio_liquido_lucas,
        t1.saldo_bradesco_lucas,
        t1.saldo_bradesco_investimentos_lucas,
        t1.saldo_nubank_investimentos_lucas,
        t1.saldo_nubank_cashback_lucas,
        t1.saldo_bitcoin_lucas,
        t1.saldo_daycoval_lucas,
        t1.saldo_avenue_lucas,
        t1.saldo_wise_lucas,
        t1.patrimonio_liquido_jessica,
        t1.saldo_banco_brasil_jessica,
        t1.saldo_sofisa_investimentos_jessica,
        t1.saldo_itau_investimentos_jessica,
        t1.saldo_nubank_investimentos_jessica,
        t1.saldo_avenue_jessica,
        t1.vlr_carro,
        t1.mes_base = MAX(t1.mes_base) OVER () AS fl_mes_atual
    FROM {{ ref('stg_patrimonio') }} AS t1
    INNER JOIN datas AS t2
        ON t1.mes_base = t2.inicio_mes
)

SELECT
    ativos.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM ativos
ORDER BY ativos.mes_base
