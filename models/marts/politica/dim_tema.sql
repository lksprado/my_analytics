{{ config(
    tags=["politica"]
) }}

WITH
temas AS (
    SELECT DISTINCT ON (codigo_tema)
        codigo_tema,
        tema
    FROM {{ ref('stg_camara_proposicao_tema') }}
    WHERE codigo_tema IS NOT NULL
    ORDER BY codigo_tema ASC, loaded_at_utc DESC
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['codigo_tema']) }} AS sk_tema,
        codigo_tema,
        {{ clean_string("tema", "upper") }}                    AS tema,
        '{{ run_started_at }}'::TIMESTAMPTZ                    AS model_run_at
    FROM temas
)

SELECT * FROM final
UNION ALL
{{ dummy_row([
    ['sk_tema', 'sk'],
    ['codigo_tema', 'null::int'],
    ['tema', 'text'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
