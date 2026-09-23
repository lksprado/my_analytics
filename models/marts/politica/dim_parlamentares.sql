{{ config(
    tags=["politica"]
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
        CASE WHEN casa = 'CAMARA' THEN radar_parlamentar_id_fk END            AS radar_deputado_id_fk,
        CASE WHEN casa = 'SENADO' THEN radar_parlamentar_id_fk END            AS radar_senador_id_fk,
        casa,
        nome,
        COALESCE(nome_completo, nome)                                         AS nome_completo,
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
    ['radar_deputado_id_fk', 'null::int'],
    ['radar_senador_id_fk', 'null::int'],
    ['casa', 'text'],
    ['nome', 'text'],
    ['nome_completo', 'text'],
    ['sexo', 'text'],
    ['uf', 'text'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
