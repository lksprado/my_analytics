{{ config(
    tags=["politica"]
) }}

WITH tipos AS (
    SELECT * FROM {{ ref('seed_tipos_voto') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['casa', 'codigo_origem']) }} AS sk_tipo_voto,
    casa,
    codigo_origem,
    descricao,
    posicao,
    categoria,
    fl_presente,
    '{{ run_started_at }}'::TIMESTAMPTZ                               AS model_run_at
FROM tipos
UNION ALL
{{ dummy_row([
    ['sk_tipo_voto', 'sk'],
    ['casa', 'text'],
    ['codigo_origem', 'text'],
    ['descricao', 'text'],
    ['posicao', 'null::text'],
    ['categoria', 'text'],
    ['fl_presente', 'null::int'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
