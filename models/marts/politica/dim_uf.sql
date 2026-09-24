{{ config(
    tags=["politica"]
) }}

WITH
final AS (
    SELECT
        uf,
        nome_uf,
        regiao,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM {{ ref('seed_ufs') }}
)

SELECT * FROM final
UNION ALL
{{ dummy_row([
    ['uf', 'text'],
    ['nome_uf', 'text'],
    ['regiao', 'text'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
