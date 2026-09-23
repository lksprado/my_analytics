{{ config(
    tags=["politica"]
) }}


WITH
senado_votacoes AS (
    SELECT
        *,
        'SENADO' AS casa
    FROM {{ ref('stg_senado_votacoes') }}
),

final AS (
    SELECT
        casa,
        votacao_id_nk,
        processo_id_nk,
        data_votacao,
        identificacao,
        aprovado,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM senado_votacoes
    WHERE votacao_id_nk IS NOT NULL
    ORDER BY data_votacao DESC

)

SELECT * FROM final
