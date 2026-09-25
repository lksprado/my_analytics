{{ config(
    tags=["politica"]
) }}


WITH source AS (
    SELECT * FROM {{ ref('seed_senado_tipos_decisao') }}
),

renamed AS (
    SELECT
        sigla                               AS codigo_deliberacao,
        descricao                           AS descricao_deliberacao,
        efeito                              AS efeito_deliberacao,
        resultado_legislativo,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM source
)

SELECT * FROM renamed
