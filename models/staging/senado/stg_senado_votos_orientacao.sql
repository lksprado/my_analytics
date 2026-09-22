{{ config(
    tags=["senado", "votacoes"]
) }}

WITH source AS (
    SELECT * FROM {{ source('senado','raw_senado_votos_orientacao') }}
)

SELECT
    codigovotacaosve::INT                 AS votacao_id_fk,
    siglatipomateria                      AS sigla_tipo_materia,
    numeromateria::BIGINT                 AS numero_materia,
    qtdvotossim::BIGINT                   AS total_votos_favor,
    qtdvotosnao::BIGINT                   AS total_votos_contra,
    qtdvotosabstencao::BIGINT             AS total_votos_abstencao,
    datahora::DATE                        AS data_votacao,
    {{ clean_string("partido","upper") }} AS partido,
    CASE
        WHEN {{ clean_string("voto","upper") }} = 'LIVRE' THEN 'LIBERADO'
        ELSE {{ clean_string("voto","upper") }}
    END                                   AS orientacao_voto,
    loaded_at_utc,
    '{{ run_started_at }}'::TIMESTAMPTZ   AS model_run_at
FROM source
