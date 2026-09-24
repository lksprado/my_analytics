{{ config(
    tags=["politica"]
) }}

WITH
final AS (
    SELECT
        legislatura::INT                    AS legislatura,
        inicio::DATE                        AS inicio,
        fim::DATE                           AS fim,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM {{ ref('seed_legislaturas') }}
)

SELECT * FROM final
