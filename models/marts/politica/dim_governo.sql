{{ config(
    tags=["politica"]
) }}

WITH
final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['presidente', 'mandato::INT']) }} AS sk_governo,
        presidente,
        mandato::INT                                                           AS mandato,
        presidente || ' (' || mandato::INT || 'º mandato)'                     AS governo,
        inicio::DATE                                                           AS inicio,
        fim::DATE                                                              AS fim,
        '{{ run_started_at }}'::TIMESTAMPTZ                                    AS model_run_at
    FROM {{ ref('seed_executivo_presidente') }}
)

SELECT * FROM final
