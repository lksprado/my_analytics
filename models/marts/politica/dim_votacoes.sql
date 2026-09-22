{{ config(
    tags=["camara", "senado", "votacoes"]
) }}

WITH
votacoes AS (
    SELECT
        casa,
        votacao_id_nk,
        data_votacao,
        proposicao_id_fk AS proposicao_ref,
        aprovado
    FROM {{ ref('int_votacoes_camara_deduplicadas') }}
    UNION ALL
    SELECT
        casa,
        votacao_id_nk,
        data_votacao,
        processo_id_nk,
        aprovado
    FROM {{ ref('int_votacoes_senado_filtradas') }}
),

deduplicada AS (
    SELECT DISTINCT ON (casa, votacao_id_nk) *
    FROM votacoes
    ORDER BY casa, votacao_id_nk
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['casa', 'votacao_id_nk']) }} AS sk_votacao,
        votacao_id_nk,
        casa,
        data_votacao,
        -- Hash de FK nula devolveria uma sk válida apontando para proposição nenhuma:
        -- 2/3 das votações da Câmara não declaram proposição objeto.
        CASE
            WHEN proposicao_ref IS NULL THEN '{{ var("null_key") }}'
            ELSE {{ dbt_utils.generate_surrogate_key(['casa', 'proposicao_ref']) }}
        END                                                               AS sk_proposicao,
        aprovado,
        CAST(TO_CHAR(data_votacao, 'YYYYMMDD') AS INTEGER)                AS sk_data,
        '{{ run_started_at }}'::TIMESTAMPTZ                               AS model_run_at
    FROM deduplicada
)

SELECT * FROM final
UNION ALL
{{ dummy_row([
    ['sk_votacao', 'sk'],
    ['votacao_id_nk', 'null::text'],
    ['casa', 'text'],
    ['data_votacao', 'null::date'],
    ['sk_proposicao', 'sk'],
    ['aprovado', 'null::int'],
    ['sk_data', '1'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
