{{ config(
    tags=["camara", "senado", "parlamentar"]
) }}

WITH
parlamentares AS (
    SELECT * FROM {{ ref('int_deputados_padronizados') }}
    UNION ALL
    SELECT * FROM {{ ref('int_senadores_padronizados') }}
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['casa', 'parlamentar_id_nk']) }} AS sk_parlamentar,
        CASE WHEN casa = 'CAMARA' THEN parlamentar_id_nk END                  AS deputado_id_nk,
        CASE WHEN casa = 'SENADO' THEN parlamentar_id_nk END                  AS senador_id_nk,
        casa,
        nome,
        nome_completo,
        sexo,
        uf,
        '{{ run_started_at }}'::TIMESTAMPTZ                                   AS model_run_at
    FROM parlamentares
)

SELECT * FROM final
UNION ALL
{{ dummy_row([
    ['sk_parlamentar', 'sk'],
    ['deputado_id_nk', 'null::int'],
    ['senador_id_nk', 'null::int'],
    ['casa', 'text'],
    ['nome', 'text'],
    ['nome_completo', 'text'],
    ['sexo', 'text'],
    ['uf', 'text'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
