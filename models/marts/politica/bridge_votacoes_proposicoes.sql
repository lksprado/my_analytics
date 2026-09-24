{{ config(
    tags=["politica"]
) }}

-- Hoje a origem só informa o objeto; AFETADA e POSSIVEL_OBJETO dependem da extração de /votacoes/{id}.
WITH
final AS (
    SELECT
        sk_votacao,
        sk_proposicao,
        'OBJETO'                            AS tipo_relacao,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM {{ ref('fct_votacoes') }}
    WHERE sk_proposicao <> '{{ var("null_key") }}'
)

SELECT * FROM final
