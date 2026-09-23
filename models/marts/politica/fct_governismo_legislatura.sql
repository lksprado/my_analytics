{{ config(
    tags=["politica"]
) }}

WITH
votos_orientados AS (
    SELECT
        t1.casa,
        t1.sk_data,
        t1.sk_voto,
        t1.sk_votacao,
        t1.sk_parlamentar,
        t1.votacao_id_fk,
        t1.deputado_id_fk,
        t1.senador_id_fk,
        t3.legislatura,
        t1.partido,
        t1.partido_nome,
        CASE WHEN t1.voto = t2.orientacao_voto THEN 1 ELSE 0 END AS voto_alinhado
    FROM {{ ref('fct_votos') }} AS t1
    INNER JOIN {{ ref('dim_orientacao_votacoes') }} AS t2
        ON t1.sk_votacao = t2.sk_votacao
        AND t2.sigla_partido_bloco = 'GOVERNO'
    LEFT JOIN {{ ref('dim_votacoes') }} AS t3
        ON t2.sk_votacao = t3.sk_votacao
),

votos_orientados_agreg AS (
    SELECT
        sk_parlamentar,
        deputado_id_fk,
        senador_id_fk,
        legislatura,
        SUM(voto_alinhado)         AS qt_votos_alinhados_legislatura,
        COUNT(DISTINCT sk_votacao) AS qt_votos_legislatura
    FROM votos_orientados
    GROUP BY
        sk_parlamentar,
        deputado_id_fk,
        senador_id_fk,
        legislatura
),

final AS (
    SELECT
        sk_parlamentar,
        deputado_id_fk,
        senador_id_fk,
        legislatura,
        qt_votos_alinhados_legislatura,
        qt_votos_legislatura,
        ROUND(100.0 * qt_votos_alinhados_legislatura / NULLIF(qt_votos_legislatura, 0), 0)::NUMERIC(3, 0) AS perc_governismo_legislatura
    FROM votos_orientados_agreg
)

SELECT
    *,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM final

