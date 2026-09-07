{{
  config(
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

WITH
consolidados AS (
    SELECT
        t1.mes_debito       AS mes,
        t1.data_debito      AS data,
        t2.fl_data_especial,
        t2.fl_mes_especial,
        t1.nome_dia         AS dia_nome,
        t1.dia_ajustado     AS dia_fatura,
        t1.dia_real         AS dia_ano,
        {#- ::INT porque day_of_month vem como double precision da dimensão de
            datas (o get_date_dimension do dbt_date usa EXTRACT, que em
            PostgreSQL devolve float). Dia do mês é contagem, não medida — e era
            a única coluna de finanças que chegava à marts em ponto flutuante. -#}
        t2.day_of_month::INT AS dia_mes,
        t2.week_of_year     AS semana,
        t2.quarter_of_year  AS trimestre,
        t2.year_number      AS ano,
        {#- Dinheiro chega à marts em reais inteiros, como no resto do domínio.
            O cast é DEPOIS do SUM, de propósito: as contas do Lucas e da Jéssica
            entram com centavos, e arredondar cada uma antes de somar erraria
            duas vezes por dia/categoria em vez de uma. Aqui arredonda-se o total
            do casal, que é o grão desta tabela. -#}
        SUM(t1.mercado)::INT     AS total_mercado,
        SUM(t1.diversos)::INT    AS total_diversos,
        SUM(t1.assinaturas)::INT AS total_assinaturas,
        SUM(t1.role)::INT        AS total_role,
        SUM(t1.transporte)::INT  AS total_transporte,
        SUM(t1.apartamento)::INT AS total_apartamento,
        SUM(t1.saude)::INT       AS total_saude,
        SUM(t1.educacao)::INT    AS total_educacao
    FROM {{ ref('int_consumo_consolidado') }} AS t1
    INNER JOIN {{ ref('dim_datas') }} AS t2
        ON t1.data_debito = t2.date_day
    WHERE mes_debito > '2023-08-01'
    GROUP BY
        t1.mes_debito,
        t1.data_debito,
        t2.fl_data_especial,
        t2.fl_mes_especial,
        t1.nome_dia,
        t1.dia_ajustado,
        t1.dia_real,
        t2.day_of_month,
        t2.week_of_year,
        t2.quarter_of_year,
        t2.year_number
    ORDER BY data_debito
)

SELECT
    consolidados.*,
    CURRENT_TIMESTAMP AS model_updated_at
FROM consolidados
