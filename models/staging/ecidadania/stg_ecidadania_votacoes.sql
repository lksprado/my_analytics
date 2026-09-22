{{ config(
    tags=["ecidadania", "participacao"]
) }}


WITH base AS (
    SELECT * FROM {{ ref('eph_ecidadania_votacoes') }}
),

renamed AS (
    SELECT
        ROW_NUMBER() OVER (PARTITION BY titulo, dt_extracao ORDER BY (votos_sim::BIGINT + votos_nao::BIGINT) DESC) AS rn,
        TO_DATE(dt_extracao, 'YYYY-MM-DD')                 AS data_extracao,
        sigla,
        numero::INT                                        AS numero,
        ano::INT                                           AS ano,
        titulo                                             AS identificacao,
        {{ clean_string('tipo_proposicao', 'upper') }}     AS tipo_proposicao,
        {{ clean_string('descritivo', 'upper') }}          AS ementa,
        votos_sim::BIGINT                                  AS votos_sim,
        votos_nao::BIGINT                                  AS votos_nao,
        (votos_sim::BIGINT + votos_nao::BIGINT)            AS total_votos,
        CASE
            WHEN votos_sim > votos_nao THEN 'A FAVOR'
            WHEN votos_nao > votos_sim THEN 'CONTRA'
            WHEN votos_nao = votos_sim THEN 'EMPATE'
        END                                                AS vontade_popular,
        link
    FROM base
    WHERE COALESCE((votos_sim::BIGINT + votos_nao::BIGINT), 0) > 0
),
final AS (
    SELECT 
        data_extracao,
        sigla
        numero,
        ano,
        identificacao,
        tipo_proposicao,
        ementa,
        votos_sim,
        votos_nao,
        total_votos,
        vontade_popular,
        link
    FROM renamed
    WHERE rn = 1
)
SELECT * FROM final
