{{ config(
    tags=["politica"]
) }}


WITH
camara_votos AS (
    SELECT
        *,
        'CAMARA' AS casa
    FROM {{ ref('stg_camara_votacoes_orientacao') }}
),

ajustes AS (
    SELECT
        casa,
        votacao_id_fk,
        orientacao_voto,
        CASE
            WHEN codigo_tipo_lideranca = 'B' THEN 'BANCADA'
            WHEN codigo_tipo_lideranca = 'P' THEN 'PARTIDO'
        END                                                            AS tipo_lideranca,
        CASE
            WHEN sigla_partido_bloco IN ('SD', 'SDD', 'SOLIDARIED', 'SOLIDARIEDADE') THEN 'SOLIDARIEDADE'
            WHEN sigla_partido_bloco IN ('PATRI', 'PATRIOTA') THEN 'PATRIOTA'
            WHEN sigla_partido_bloco IN ('FDR PSDBCIDADAN', 'FDR PSDBCIDADANIA') THEN 'FDR PSDBCIDADANIA'
            ELSE sigla_partido_bloco
        END                                                            AS sigla_partido_bloco
    FROM camara_votos
    WHERE orientacao_voto IS NOT NULL
),

final AS (
    SELECT
        votacao_id_fk,
        casa,
        orientacao_voto,
        -- A origem às vezes omite o tipo; vale o da sigla nas outras orientações.
        MAX(tipo_lideranca) OVER (PARTITION BY sigla_partido_bloco) AS tipo_lideranca,
        sigla_partido_bloco,
        '{{ run_started_at }}'::TIMESTAMPTZ                          AS model_run_at
    FROM ajustes
)

SELECT * FROM final
