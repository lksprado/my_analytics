{{ config(
    tags=["politica"]
) }}

WITH
partidos AS (
    SELECT
        id_senado,
        sigla_camara,
        sigla_senado,
        sigla_conformada,
        data_criacao,
        COALESCE(data_extincao, DATE '9999-12-31') AS data_extincao
    FROM {{ ref('seed_partidos') }}
),

-- A seed tem grão por id_camara: a vigência da entidade é a união das suas linhas.
vigencia AS (
    SELECT
        id_senado,
        MIN(data_criacao)  AS inicio,
        MAX(data_extincao) AS fim
    FROM partidos
    GROUP BY id_senado
),

siglas AS (
    SELECT
        id_senado,
        sigla_camara AS sigla
    FROM partidos
    UNION
    SELECT
        id_senado,
        sigla_senado
    FROM partidos
    UNION
    SELECT
        id_senado,
        REPLACE(sigla_conformada, '*', '')
    FROM partidos
    UNION
    SELECT
        id_senado,
        sigla
    FROM {{ ref('seed_partidos_siglas') }}
)

SELECT DISTINCT
    {{ clean_string("s.sigla", "upper") }} AS sigla,
    s.id_senado                            AS partido_id_senado,
    v.inicio,
    v.fim,
    '{{ run_started_at }}'::TIMESTAMPTZ    AS model_run_at
FROM siglas AS s
INNER JOIN vigencia AS v
    ON s.id_senado = v.id_senado
