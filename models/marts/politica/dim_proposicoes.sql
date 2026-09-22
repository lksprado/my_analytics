{{ config(
    tags=["dim","senado"]
) }}

with
proposicoes_unificadas as (
    select
        sk_proposicao,
        casa,
        proposicao_id_nk,
        tipo_proposicao,
        data_proposicao,
        sk_data,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    from {{ ref('int_proposicoes_unificadas') }}
)

select * from proposicoes_unificadas
union all
{{ dummy_row([
    ['sk_proposicao', 'sk'],
    ['casa', 'text'],
    ['proposicao_id_nk', 'null::int'],
    ['tipo_proposicao', 'text'],
    ['data_proposicao', 'null::date'],
    ['sk_data', '1'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
