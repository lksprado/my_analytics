{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}

WITH
investimentos AS (
    SELECT
    COALESCE(t1.mes_base, t2.mes_base) AS mes_base,
    COALESCE(t1.bradesco_investimentos_lucas, 0 ) AS bradesco_investimentos_lucas,
    COALESCE(t1.nubank_investimentos_lucas, 0 ) AS nubank_investimentos_lucas,
    COALESCE(t1.avenue_lucas, 0 ) AS avenue_lucas,
    COALESCE(t1.daycoval_lucas, 0 ) AS daycoval_lucas,
    COALESCE(t1.sofisa_investimentos_jessica, 0 ) AS sofisa_investimentos_jessica,
    COALESCE(t1.itau_investimentos_jessica, 0 ) AS itau_investimentos_jessica,
    COALESCE(t1.nubank_investimentos_jessica, 0 ) AS nubank_investimentos_jessica,
    COALESCE(t1.avenue_jessica, 0 ) AS avenue_jessica,
    COALESCE(t2.bradesco_investimentos_deusa, 0 ) AS bradesco_investimentos_deusa,
    COALESCE(t2.banco_brasil_investimentos_deusa, 0 ) AS banco_brasil_investimentos_deusa,
    COALESCE(t2.nubank_investimentos_deusa, 0 ) AS nubank_investimentos_deusa,
    COALESCE(t2.avenue_deusa, 0 ) AS avenue_deusa,
    'GOOGLE SHEETS' AS fonte_dado
    FROM {{ ref('stg_patrimonio') }} t1 
    FULL JOIN {{ ref('stg_patrimonio_deusa') }} t2
    ON t1.mes_base = t2.mes_base
)
select *,
'{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
from investimentos order by mes_base