{{ config(
    tags=["camara", "senado", "parlamentar", "votacoes"]
) }}

WITH governismo_por_parlamentar_legislatura AS (
    SELECT *  FROM {{ ref('governismo_por_parlamentar_legislatura') }}
),
scored AS (
    SELECT
        *,
        AVG(qt_votos)        OVER (PARTITION BY legislatura, casa) AS _prior_votos,
        AVG(perc_governismo) OVER (PARTITION BY legislatura, casa) AS _prior_governismo
    FROM governismo_por_parlamentar_legislatura
)
SELECT
    casa,
    sk_parlamentar,
    deputado_id_nk,
    senador_id_nk,
    legislatura,
    qt_votos,
    qt_votacoes,
    qt_votos_alinhados,
    qt_votos_nao_alinhados,
    perc_governismo,
    ROUND(
        (qt_votos * perc_governismo + _prior_votos * _prior_governismo)
        / NULLIF(qt_votos + _prior_votos, 0)
    , 2) AS score_governismo_ponderado
FROM scored
