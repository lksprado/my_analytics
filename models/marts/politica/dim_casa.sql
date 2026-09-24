{{ config(
    tags=["politica"]
) }}

WITH
casas (casa, nome_casa) AS (
    VALUES
    ('CAMARA', 'Câmara dos Deputados'),
    ('SENADO', 'Senado Federal')
),

final AS (
    SELECT
        casa,
        nome_casa,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM casas
)

SELECT * FROM final
UNION ALL
{{ dummy_row([
    ['casa', 'text'],
    ['nome_casa', 'text'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
