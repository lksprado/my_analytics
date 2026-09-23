{{ config(
    tags=["politica"]
) }}

WITH
partidos AS (
    SELECT * FROM {{ ref('seed_partidos') }}
),

-- O registro de maior id_camara é o rebrand vigente da entidade.
atual AS (
    SELECT DISTINCT ON (id_senado)
        id_senado,
        REPLACE(sigla_conformada, '*', '') AS sigla,
        nome
    FROM partidos
    ORDER BY id_senado ASC, id_camara DESC
),

historico AS (
    SELECT
        id_senado,
        STRING_AGG(DISTINCT sigla_camara, ', ' ORDER BY sigla_camara)         AS siglas_historicas,
        MIN(data_criacao)                                                     AS data_criacao,
        -- Extinta só quando todas as siglas da entidade foram extintas.
        CASE WHEN COUNT(*) = COUNT(data_extincao) THEN MAX(data_extincao) END AS data_extincao
    FROM partidos
    GROUP BY id_senado
),

entidades AS (
    SELECT
        a.id_senado,
        {{ clean_string("a.sigla", "upper") }} AS sigla,
        {{ clean_string("a.nome", "upper") }}  AS nome,
        h.siglas_historicas,
        h.data_criacao,
        h.data_extincao
    FROM atual AS a
    INNER JOIN historico AS h
        ON a.id_senado = h.id_senado
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['id_senado']) }} AS sk_partido,
        id_senado                                             AS partido_id_nk,
        sigla,
        nome,
        siglas_historicas,
        data_criacao,
        data_extincao,
        data_extincao IS NOT NULL                             AS fl_extinto,
        -- Sigla reutilizada: a entidade extinta leva o período no rótulo.
        CASE
            WHEN data_extincao IS NOT NULL AND COUNT(*) OVER (PARTITION BY sigla) > 1
                THEN sigla || ' (' || EXTRACT(YEAR FROM data_criacao) || '-' || EXTRACT(YEAR FROM data_extincao) || ')'
            ELSE sigla
        END                                                   AS rotulo,
        '{{ run_started_at }}'::TIMESTAMPTZ                   AS model_run_at
    FROM entidades
)

SELECT * FROM final
UNION ALL
{{ dummy_row([
    ['sk_partido', 'sk'],
    ['partido_id_nk', 'null::int'],
    ['sigla', 'text'],
    ['nome', 'text'],
    ['siglas_historicas', 'null::text'],
    ['data_criacao', 'null::date'],
    ['data_extincao', 'null::date'],
    ['fl_extinto', 'null::boolean'],
    ['rotulo', 'text'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
