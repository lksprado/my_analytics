{{ config(
    tags=["politica"]
) }}

WITH source AS (
    SELECT * FROM {{ ref('seed_senado_tipos_projetos') }}
)

SELECT
    sigla                                    AS sigla_proposicao,
    {{ clean_string("descricao", "upper") }} AS descricao_proposicao,
    "dataInicio"                             AS data_inicio,
    "dataFim"                                AS data_fim,
    '{{ run_started_at }}'::TIMESTAMPTZ      AS model_run_at
FROM source
