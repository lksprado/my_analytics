{{ config(
    tags=["politica"]
) }}

WITH
indicadores AS (
    SELECT * FROM {{ ref('int_indicadores_radar_versoes') }}
    UNION ALL
    SELECT * FROM {{ ref('int_indicadores_ranking_versoes') }}
),

parlamentares AS (
    SELECT
        sk_parlamentar,
        casa,
        COALESCE(deputado_id_nk, senador_id_nk)             AS parlamentar_casa_id,
        COALESCE(radar_deputado_id_fk, radar_senador_id_fk) AS radar_id
    FROM {{ ref('dim_parlamentares') }}
),

-- Radar e Ranking identificam o parlamentar de formas diferentes: um lookup por fonte.
final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['i.fonte', 'i.indicador', 'i.casa', 'i.parlamentar_fonte_id_nk', 'i.periodo_inicio', 'i.data_coleta']) }} AS sk_indicador_valor,
        {{ dbt_utils.generate_surrogate_key(['i.fonte', 'i.indicador']) }}                                                                             AS sk_indicador_externo,
        COALESCE(pr.sk_parlamentar, pc.sk_parlamentar, '{{ var("null_key") }}')                                                                        AS sk_parlamentar,
        i.casa,
        i.parlamentar_fonte_id_nk,
        i.periodo_tipo,
        i.periodo_inicio,
        i.periodo_fim,
        i.valor_original,
        i.qt_base,
        i.data_coleta,
        i.data_fim_vigencia,
        (i.data_fim_vigencia IS NULL)::INT                                                                                                             AS fl_versao_vigente,
        '{{ run_started_at }}'::TIMESTAMPTZ                                                                                                            AS model_run_at
    FROM indicadores AS i
    LEFT JOIN parlamentares AS pr
        ON i.fonte = 'RADAR CONGRESSO'
        AND i.casa = pr.casa
        AND i.parlamentar_fonte_id_nk::INT = pr.radar_id
    LEFT JOIN parlamentares AS pc
        ON i.fonte = 'RANKING DOS POLITICOS'
        AND i.casa = pc.casa
        AND i.parlamentar_casa_id = pc.parlamentar_casa_id
)

SELECT * FROM final
