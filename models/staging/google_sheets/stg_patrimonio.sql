{{
  config(
    tags = ['financas', 'staging'],
  )
}}

WITH
source AS (
    SELECT * FROM {{ source('google_finance_sheet', 'patrimonio') }}
),

renamed AS (
    SELECT
        REGEXP_REPLACE(patrimonio_total, '[^0-9]', '', 'g')::INT       AS total_patrimonio_bruto,

        REGEXP_REPLACE(patrimonio_r$, '[^0-9]', '', 'g')::INT          AS total_patrimonio_liquido,
        REGEXP_REPLACE(patrimonio_lucas_r$, '[^0-9]', '', 'g')::INT    AS patrimonio_liquido_lucas,
        REGEXP_REPLACE(bradesco_saldo, '[^0-9]', '', 'g')::INT         AS saldo_bradesco_lucas,
        REGEXP_REPLACE(nubank_saldo_l, '[^0-9]', '', 'g')::INT         AS saldo_nubank_lucas,

        REGEXP_REPLACE(bradesco_investimentos, '[^0-9]', '', 'g')::INT AS bradesco_investimentos_lucas,
        REGEXP_REPLACE(nubank_investimentos_l, '[^0-9]', '', 'g')::INT AS nubank_investimentos_lucas,
        REGEXP_REPLACE(nubank_cashback, '[^0-9]', '', 'g')::INT        AS saldo_nubank_cashback_lucas,
        REGEXP_REPLACE(bitcoin, '[^0-9]', '', 'g')::INT                AS saldo_bitcoin_lucas,
        REGEXP_REPLACE(daycoval, '[^0-9]', '', 'g')::INT               AS daycoval_lucas,
        REGEXP_REPLACE(avenue_l, '[^0-9]', '', 'g')::INT               AS avenue_lucas,
        REGEXP_REPLACE(wise, '[^0-9]', '', 'g')::INT                   AS saldo_wise_lucas,
        REGEXP_REPLACE(patrimonio_jessica_r$, '[^0-9]', '', 'g')::INT  AS patrimonio_liquido_jessica,

        {#- Colunas repetidas na planilha ganham sufixo _1 na carga; o bloco de Jéssica vem depois do de Lucas. -#}
        REGEXP_REPLACE(banco_brasil_saldo, '[^0-9]', '', 'g')::INT     AS saldo_banco_brasil_jessica,
        REGEXP_REPLACE(nubank_saldo_j, '[^0-9]', '', 'g')::INT         AS saldo_nubank_jessica,
        REGEXP_REPLACE(sofisa, '[^0-9]', '', 'g')::INT                 AS sofisa_investimentos_jessica,
        REGEXP_REPLACE(itau, '[^0-9]', '', 'g')::INT                   AS itau_investimentos_jessica,
        REGEXP_REPLACE(nubank_investimentos_j, '[^0-9]', '', 'g')::INT AS nubank_investimentos_jessica,
        REGEXP_REPLACE(avenue_j, '[^0-9]', '', 'g')::INT               AS avenue_jessica,
        REGEXP_REPLACE(carro, '[^0-9]', '', 'g')::INT                  AS vlr_carro,
        (REPLACE(
            REPLACE(REGEXP_REPLACE(minha_inflacao, '[^0-9,.]', '', 'g'), '.', ''),
            ',',
            '.'
        )::NUMERIC / 100)::NUMERIC(18, 3)                              AS minha_inflacao,
        (REPLACE(
            REPLACE(REGEXP_REPLACE(ipca, '[^0-9,.]', '', 'g'), '.', ''),
            ',',
            '.'
        )::NUMERIC / 100)::NUMERIC(18, 3)                              AS ipca,
        (REPLACE(
            REPLACE(REGEXP_REPLACE(igpm, '[^0-9,.]', '', 'g'), '.', ''),
            ',',
            '.'
        )::NUMERIC / 100)::NUMERIC(18, 3)                              AS igpm,
        (REPLACE(
            REPLACE(REGEXP_REPLACE(selic, '[^0-9,.]', '', 'g'), '.', ''),
            ',',
            '.'
        )::NUMERIC / 100)::NUMERIC(18, 3)                              AS selic,

        (REPLACE(
            REPLACE(REGEXP_REPLACE(cdi, '[^0-9,.]', '', 'g'), '.', ''),
            ',',
            '.'
        )::NUMERIC / 100)::NUMERIC(18, 3)                              AS cdi,
        REPLACE("minha_inflacao_acum.", ',', '.')::NUMERIC(18, 3)      AS minha_inflacao_acum,

        REPLACE("ipca_acum.", ',', '.')::NUMERIC(18, 3)                AS ipca_acum,
        REPLACE("igpm_acum.", ',', '.')::NUMERIC(18, 3)                AS igpm_acum,
        REPLACE("selic_acum.", ',', '.')::NUMERIC(18, 3)               AS selic_acum,
        REPLACE("cdi_acum.", ',', '.')::NUMERIC(18, 3)                 AS cdi_acum,
        TO_DATE(
            CASE
                WHEN mes LIKE 'jan.%' THEN '01/' || RIGHT(mes, 2)
                WHEN mes LIKE 'fev.%' THEN '02/' || RIGHT(mes, 2)
                WHEN mes LIKE 'mar.%' THEN '03/' || RIGHT(mes, 2)
                WHEN mes LIKE 'abr.%' THEN '04/' || RIGHT(mes, 2)
                WHEN mes LIKE 'mai.%' THEN '05/' || RIGHT(mes, 2)
                WHEN mes LIKE 'jun.%' THEN '06/' || RIGHT(mes, 2)
                WHEN mes LIKE 'jul.%' THEN '07/' || RIGHT(mes, 2)
                WHEN mes LIKE 'ago.%' THEN '08/' || RIGHT(mes, 2)
                WHEN mes LIKE 'set.%' THEN '09/' || RIGHT(mes, 2)
                WHEN mes LIKE 'out.%' THEN '10/' || RIGHT(mes, 2)
                WHEN mes LIKE 'nov.%' THEN '11/' || RIGHT(mes, 2)
                WHEN mes LIKE 'dez.%' THEN '12/' || RIGHT(mes, 2)
            END, 'MM/YY'
        )                                                              AS mes_base
    FROM source
),

nulls_treated AS (
    {#- Saldos em branco são zero, mas os indexadores atravessam sem COALESCE: NULL
        ali é "o IPCA do mês ainda não saiu", e é o que o portão pronto_indicadores
        lê. Zero faria o portão passar com um IPCA inventado. -#}
    SELECT
        mes_base,
        minha_inflacao,
        ipca,
        igpm,
        selic,
        cdi,
        minha_inflacao_acum,
        ipca_acum,
        igpm_acum,
        selic_acum,
        cdi_acum,
        COALESCE(total_patrimonio_bruto, 0)       AS total_patrimonio_bruto,
        COALESCE(total_patrimonio_liquido, 0)     AS total_patrimonio_liquido,
        COALESCE(patrimonio_liquido_lucas, 0)     AS patrimonio_liquido_lucas,
        COALESCE(saldo_bradesco_lucas, 0)         AS saldo_bradesco_lucas,
        COALESCE(saldo_nubank_lucas, 0)           AS saldo_nubank_lucas,
        COALESCE(bradesco_investimentos_lucas, 0) AS bradesco_investimentos_lucas,
        COALESCE(nubank_investimentos_lucas, 0)   AS nubank_investimentos_lucas,
        COALESCE(saldo_nubank_cashback_lucas, 0)  AS saldo_nubank_cashback_lucas,
        COALESCE(saldo_bitcoin_lucas, 0)          AS saldo_bitcoin_lucas,
        COALESCE(daycoval_lucas, 0)               AS daycoval_lucas,
        COALESCE(avenue_lucas, 0)                 AS avenue_lucas,
        COALESCE(saldo_wise_lucas, 0)             AS saldo_wise_lucas,
        COALESCE(patrimonio_liquido_jessica, 0)   AS patrimonio_liquido_jessica,
        COALESCE(saldo_banco_brasil_jessica, 0)   AS saldo_banco_brasil_jessica,
        COALESCE(saldo_nubank_jessica, 0)         AS saldo_nubank_jessica,
        COALESCE(sofisa_investimentos_jessica, 0) AS sofisa_investimentos_jessica,
        COALESCE(itau_investimentos_jessica, 0)   AS itau_investimentos_jessica,
        COALESCE(nubank_investimentos_jessica, 0) AS nubank_investimentos_jessica,
        COALESCE(avenue_jessica, 0)               AS avenue_jessica,
        COALESCE(vlr_carro, 0)                    AS vlr_carro,
        '{{ run_started_at }}'::TIMESTAMPTZ       AS model_run_at
    FROM renamed
)

SELECT * FROM nulls_treated
WHERE mes_base > '2023-08-01'
