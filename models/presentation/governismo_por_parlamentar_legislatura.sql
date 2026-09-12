{{ config(
    tags=["camara", "senado", "parlamentar", "votacoes"]
) }}

WITH governismo AS (
    SELECT
        casa,
        sk_parlamentar,
        deputado_id_nk,
        senador_id_nk,
        nome,
        uf,
        legislatura,
        COUNT(sk_voto) AS qt_votos,
        COUNT(DISTINCT sk_votacao) AS qt_votacoes,
        COUNT(sk_voto) FILTER (WHERE voto_alinhado = 1) AS qt_votos_alinhados,
        COUNT(sk_voto) FILTER (WHERE voto_alinhado = 0) AS qt_votos_nao_alinhados,
        ROUND(100.0 * COUNT(sk_voto) FILTER (WHERE voto_alinhado = 1)::NUMERIC / NULLIF(COUNT(sk_voto), 0),2) AS perc_governismo
    FROM {{ ref('governismo') }}
    GROUP BY
        casa,
        sk_parlamentar,
        deputado_id_nk,
        senador_id_nk,
        nome,
        uf,
        legislatura
)
SELECT *
FROM governismo