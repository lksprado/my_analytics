{{ config(
    tags=["senado", "legislacao"]
) }}

WITH source AS (
    SELECT * FROM {{ ref('seed_senado_tipos_projetos') }}
)

SELECT
    sigla        AS sigla_proposicao,
    descricao    AS descricao_proposicao,
    "dataInicio" AS data_inicio,
    "dataFim"    AS data_fim
FROM source
