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
        COALESCE(voto, 'NAO INFORMADO') AS codigo_voto
    FROM {{ ref('stg_camara_votos_deputados') }}
),

votos_com_partidos AS (
    SELECT
        t1.casa,
        t1.deputado_id_nk,
        t1.partido_id_fk,
        t2.id_senado                                                       AS partido_id_senado,
        t1.votacao_id_fk,
        {{ clean_string("REPLACE(t2.sigla_conformada,'*','')", "upper") }} AS partido,
        {{ clean_string("t2.nome", "upper") }}                             AS partido_nome,
        t1.codigo_voto,
        '{{ run_started_at }}'::TIMESTAMPTZ                                AS model_run_at
    FROM camara_votos AS t1
    LEFT JOIN {{ ref('seed_partidos') }} AS t2
        ON t1.partido_id_fk = t2.id_camara
)

SELECT * FROM votos_com_partidos
