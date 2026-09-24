{{ config(
    tags=["politica"]
) }}

WITH
final AS (
    SELECT
        f.sk_indicador_valor,
        f.sk_parlamentar,
        f.casa,
        p.nome,
        i.fonte,
        i.indicador,
        i.descricao,
        i.unidade,
        i.escala,
        f.parlamentar_fonte_id_nk,
        f.periodo_tipo,
        f.periodo_inicio,
        f.periodo_fim,
        f.valor_original,
        f.qt_base,
        f.data_coleta,
        f.data_fim_vigencia,
        f.fl_versao_vigente,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM {{ ref('fct_indicadores_externos') }} AS f
    INNER JOIN {{ ref('dim_indicador_externo') }} AS i
        ON f.sk_indicador_externo = i.sk_indicador_externo
    LEFT JOIN {{ ref('dim_parlamentares') }} AS p
        ON f.sk_parlamentar = p.sk_parlamentar
)

SELECT * FROM final
