{{ config(
    tags=["politica"]
) }}

WITH scores AS (
    SELECT * FROM {{ ref('int_parlamentares_pontuacao_explodida') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['casa', 'congresso_id_fk']) }} AS sk_parlamentar,
    ano,
    pontuacao,
    nota_base_votacoes,
    nota_base_gastos,
    nota_base_presenca,
    nota_base_privilegios,
    bonus_processos,
    bonus_producao_legislativa,
    bonus_articulacao_legislativa,
    '{{ run_started_at }}'::TIMESTAMPTZ                                 AS model_run_at
FROM scores
UNION ALL
{{ dummy_row([
    ['sk_parlamentar', 'sk'],
    ['ano', 'null::int'],
    ['pontuacao', 'null::numeric'],
    ['nota_base_votacoes', 'null::numeric'],
    ['nota_base_gastos', 'null::numeric'],
    ['nota_base_presenca', 'null::numeric'],
    ['nota_base_privilegios', 'null::numeric'],
    ['bonus_processos', 'null::numeric'],
    ['bonus_producao_legislativa', 'null::numeric'],
    ['bonus_articulacao_legislativa', 'null::numeric'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
