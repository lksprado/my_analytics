{{ config(
    tags=["politica"]
) }}

WITH
composicao AS (
    SELECT
        casa,
        sigla_bancada,
        {{ clean_string("partido", "upper") }} AS partido,
        inicio::DATE                           AS inicio,
        fim::DATE                              AS fim
    FROM {{ ref('seed_bancadas_composicao') }}
),

-- A sigla do partido é resolvida para a entidade vigente no início da participação.
resolvida AS (
    SELECT
        c.*,
        s.partido_id_senado
    FROM composicao AS c
    LEFT JOIN {{ ref('int_partidos_siglas') }} AS s
        ON c.partido = s.sigla
        AND c.inicio BETWEEN s.inicio AND s.fim
),

final AS (
    SELECT
        b.sk_bancada,
        COALESCE(p.sk_partido, '{{ var("null_key") }}') AS sk_partido,
        r.casa,
        r.sigla_bancada,
        b.tipo_bancada,
        r.inicio,
        r.fim,
        '{{ run_started_at }}'::TIMESTAMPTZ             AS model_run_at
    FROM resolvida AS r
    LEFT JOIN {{ ref('dim_bancada') }} AS b
        ON r.casa = b.casa
        AND r.sigla_bancada = b.sigla_bancada
        AND b.tipo_bancada IN ('FEDERACAO', 'BLOCO')
    LEFT JOIN {{ ref('dim_partidos') }} AS p
        ON r.partido_id_senado = p.partido_id_nk
)

SELECT * FROM final
