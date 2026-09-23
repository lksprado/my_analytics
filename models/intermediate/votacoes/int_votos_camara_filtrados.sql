{{ config(
    tags=["politica"]
) }}


WITH
camara_votos AS (
    SELECT
        *,
        'CAMARA' AS casa
    FROM {{ ref('stg_camara_votos_deputados') }}
),

votos_filtrados AS (
    SELECT
        casa,
        deputado_id_nk,
        partido_id_fk,
        votacao_id_fk,
        CASE
            WHEN voto = 'FAVORAVEL COM RESTRICOES' THEN 'SIM'
            ELSE voto
        END                                                                          AS voto
    FROM camara_votos
    WHERE voto NOT IN ('ARTIGO 17', 'BRANCO', 'ABSTENCAO')
),
votos_com_partidos AS (
    SELECT 
        t1.casa,
        t1.deputado_id_nk,
        t1.partido_id_fk,
        t1.votacao_id_fk,
        {{ clean_string("REPLACE(t2.sigla_conformada,'*','')", "upper") }} AS partido,
        {{ clean_string("t2.nome", "upper") }}          AS partido_nome,
        t1.voto,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM votos_filtrados t1
    LEFT JOIN {{ ref('seed_partidos') }} t2
    ON t1.partido_id_fk = t2.id_camara
)

SELECT * FROM votos_com_partidos
