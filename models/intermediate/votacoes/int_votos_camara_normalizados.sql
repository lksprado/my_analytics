{{ config(
    tags=["politica"]
) }}


WITH
camara_votos AS (
    SELECT
        'CAMARA'                        AS casa,
        deputado_id_nk,
        partido_id_fk,
        votacao_id_fk,
        uf,
        COALESCE(voto, 'NAO INFORMADO') AS codigo_voto,
        loaded_at_utc
    FROM {{ ref('stg_camara_votos_deputados') }}
),

-- MATERIALIZED: sem ele o Postgres expande a CTE e limpa a sigla a cada voto, a cada leitura da view.
partidos AS MATERIALIZED (
    SELECT
        id_camara,
        id_senado,
        {{ clean_string("REPLACE(sigla_conformada,'*','')", "upper") }} AS partido,
        {{ clean_string("nome", "upper") }}                             AS partido_nome
    FROM {{ ref('seed_partidos') }}
),

votos_com_partidos AS (
    SELECT
        t1.casa,
        t1.deputado_id_nk,
        t1.partido_id_fk,
        t2.id_senado                        AS partido_id_senado,
        t1.votacao_id_fk,
        t2.partido,
        t2.partido_nome,
        t1.uf,
        t1.codigo_voto,
        t1.loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM camara_votos AS t1
    LEFT JOIN partidos AS t2
        ON t1.partido_id_fk = t2.id_camara
)

SELECT * FROM votos_com_partidos
