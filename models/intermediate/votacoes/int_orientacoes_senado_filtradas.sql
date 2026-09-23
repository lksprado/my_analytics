{{ config(
    tags=["politica"]
) }}


WITH
senado_votos AS (
    SELECT
        *,
        'SENADO' AS casa
    FROM {{ ref('stg_senado_votos_orientacao') }}
),

final AS (
    SELECT
        casa,
        votacao_id_fk,
        numero_materia,
        sigla_tipo_materia,
        partido,
        orientacao_voto,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM senado_votos
    WHERE
        orientacao_voto IS NOT NULL
        AND orientacao_voto NOT IN ('ABSTENCAO', 'LIBERADO')
)

SELECT * FROM final
