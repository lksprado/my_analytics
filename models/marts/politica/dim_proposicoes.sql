{{ config(
    tags=["politica"]
) }}

WITH proposicoes AS (
    SELECT * FROM {{ ref('int_proposicoes_unificadas') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['casa', 'proposicao_id_nk']) }} AS sk_proposicao,
    casa,
    proposicao_id_nk,
    tipo_proposicao,
    data_proposicao,
    CAST(TO_CHAR(data_proposicao, 'YYYYMMDD') AS INTEGER)                AS sk_data,
    '{{ run_started_at }}'::TIMESTAMPTZ                                  AS model_run_at
FROM proposicoes
UNION ALL
{{ dummy_row([
    ['sk_proposicao', 'sk'],
    ['casa', 'text'],
    ['proposicao_id_nk', 'null::int'],
    ['tipo_proposicao', 'text'],
    ['data_proposicao', 'null::date'],
    ['sk_data', '1'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
