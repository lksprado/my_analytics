{{ config(
    tags=["politica"]
) }}

WITH
unioned AS (
    SELECT
        casa,
        votacao_id_fk,
        tipo_lideranca,
        sigla_partido_bloco,
        orientacao_voto
    FROM {{ ref('int_orientacoes_camara_corrigidas') }}
    UNION ALL
    SELECT
        casa,
        votacao_id_fk,
        '{{ var('null_string') }}',
        partido,
        orientacao_voto
    FROM {{ ref('int_orientacoes_senado_filtradas') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['casa', 'votacao_id_fk']) }} AS sk_votacao,
    tipo_lideranca,
    sigla_partido_bloco,
    orientacao_voto,
    '{{ run_started_at }}'::TIMESTAMPTZ                               AS model_run_at
FROM unioned
UNION ALL
{{ dummy_row([
    ['sk_votacao', 'sk'],
    ['tipo_lideranca', 'text'],
    ['sigla_partido_bloco', 'text'],
    ['orientacao_voto', 'text'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
