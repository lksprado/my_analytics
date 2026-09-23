{{
  config(
    tags = ['financas', 'marts'],
  )
}}

WITH
-- motivo varia dentro do mês: com ele no DISTINCT o mês duplicaria no join.
datas AS (
    SELECT
        inicio_mes,
        MAX(trimestre_do_ano) AS trimestre_do_ano,
        MAX(ano)              AS ano,
        MAX(fl_mes_especial)  AS fl_mes_especial,
        COALESCE(
            STRING_AGG(DISTINCT NULLIF(motivo, 'NORMAL'), ' / '),
            'NORMAL'
        )                     AS motivo
    FROM {{ ref('dim_datas') }}
    GROUP BY inicio_mes
),

consolidados AS (
    SELECT
        t1.mes_debito,
        t2.fl_mes_especial,
        t2.motivo,
        t2.trimestre_do_ano                         AS trimestre,
        t2.ano,
        SUM(t1.receita_total)                       AS total_receita,
        SUM(t1.despesas_total)                      AS total_despesas,
        SUM(t1.receita_total) - SUM(despesas_total) AS resultado,
        SUM(t1.ajuste_realizado)                    AS ajuste_realizado,
        SUM(t1.salario)                             AS total_salario,
        SUM(t1.dividendos)                          AS total_dividendo,
        SUM(t1.outros)                              AS total_outros,
        SUM(t1.mercado)                             AS total_mercado,
        SUM(t1.diversos)                            AS total_diversos,
        SUM(t1.assinaturas)                         AS total_assinaturas,
        SUM(t1.role)                                AS total_role,
        SUM(t1.transporte)                          AS total_transporte,
        SUM(t1.apartamento)                         AS total_apartamento,
        SUM(t1.saude)                               AS total_saude,
        SUM(t1.educacao)                            AS total_educacao

    FROM {{ ref('int_dre_consolidado') }} AS t1
    INNER JOIN datas AS t2
        ON t1.mes_debito = t2.inicio_mes
    WHERE t1.mes_debito > '2023-08-01'
    GROUP BY
        t1.mes_debito,
        t2.fl_mes_especial,
        t2.motivo,
        t2.trimestre_do_ano,
        t2.ano
    ORDER BY t1.mes_debito
)

SELECT
    consolidados.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM consolidados
