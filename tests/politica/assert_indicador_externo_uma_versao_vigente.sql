{{ config(tags=["politica"]) }}

-- Cada indicador publicado tem uma única versão vigente por parlamentar e período.
SELECT
    sk_indicador_externo,
    casa,
    parlamentar_fonte_id_nk,
    periodo_tipo,
    periodo_inicio,
    COUNT(*) AS qt_vigentes
FROM {{ ref('fct_indicadores_externos') }}
WHERE fl_versao_vigente = 1
GROUP BY sk_indicador_externo, casa, parlamentar_fonte_id_nk, periodo_tipo, periodo_inicio
HAVING COUNT(*) > 1
