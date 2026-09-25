{{ config(
    tags=["politica"]
) }}

WITH
final AS (
    SELECT
        t1.data_extracao,
        t1.total_proposicoes_votadas,
        t1.total_pessoas_votaram,
        t1.total_votos_registrados,
        t1.votos_por_pessoa,
        t2.ano,
        t2.mes_do_ano,
        t2.dia_do_ano,
        t2.nome_dia_semana,
        t2.nome_dia_semana_abrev,
        t2.nome_mes,
        t2.nome_mes_abrev,
        t2.fl_fim_de_semana,
        t2.fl_feriado,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM {{ ref('stg_ecidadania_bignumbers') }} AS t1
    LEFT JOIN {{ ref('dim_datas') }} AS t2
        ON CAST(TO_CHAR(t1.data_extracao, 'YYYYMMDD') AS INTEGER) = t2.data_sk
)

SELECT * FROM final
