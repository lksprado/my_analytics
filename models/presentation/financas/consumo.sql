{{
  config(
    tags = ['financas', 'marts'],
  )
}}

WITH
consolidados AS (
    SELECT
        t1.mes_debito            AS mes,
        t1.data_debito           AS data,
        t2.fl_data_especial,
        t2.fl_mes_especial,
        t1.nome_dia              AS dia_nome,
        t1.dia_ajustado          AS dia_fatura,
        t1.dia_real              AS dia_ano,
        t2.dia_do_mes::INT       AS dia_mes,
        t2.semana_do_ano         AS semana,
        t2.trimestre_do_ano      AS trimestre,
        t2.ano,
        {#- Cast depois do SUM: arredondar cada conta antes de somar erraria duas vezes. -#}
        
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
        ON t1.data_debito = t2.data
    WHERE mes_debito > '2023-08-01'
    GROUP BY
        t1.mes_debito,
        t1.data_debito,
        t2.fl_data_especial,
        t2.fl_mes_especial,
        t1.nome_dia,
        t1.dia_ajustado,
        t1.dia_real,
        t2.dia_do_mes,
        t2.semana_do_ano,
        t2.trimestre_do_ano,
        t2.ano
    ORDER BY data_debito
)

SELECT
    consolidados.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM consolidados
