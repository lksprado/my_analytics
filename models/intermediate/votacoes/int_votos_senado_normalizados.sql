{{ config(
    tags=["politica"]
) }}

WITH
senado_votos AS (
    SELECT
        *,
        'SENADO' AS casa
    FROM {{ ref('stg_senado_votos_senadores') }}
),

votos_filtrados AS (
    SELECT
        casa,
        senador_id_nk,
        votacao_id_fk,
        sigla_partido,
        data_votacao,
        identificacao,
        COALESCE(sigla_voto, 'NAO INFORMADO') AS codigo_voto
    FROM senado_votos
    WHERE votacao_id_fk IS NOT NULL
),

partidos_norm AS (
    SELECT
        id_senado,
        id_camara,
        {{ clean_string('sigla_senado', 'upper') }}        AS sigla_senado,
        {{ clean_string('sigla_conformada', 'upper') }}    AS partido_sigla,
        {{ clean_string('nome', 'upper') }}                AS partido_nome,
        data_criacao,
        COALESCE(data_extincao, DATE '9999-12-31')         AS data_extincao
    FROM {{ ref('seed_partidos') }}
),

-- A seed tem grão por id_camara: várias linhas por id_senado.
partidos_vigencia AS (
    SELECT
        id_senado,
        MIN(data_criacao)  AS data_criacao,
        MAX(data_extincao) AS data_extincao
    FROM partidos_norm
    GROUP BY id_senado
),

-- O registro mais recente reflete o rebrand vigente do partido.
partidos_canonico AS (
    SELECT DISTINCT ON (id_senado)
        id_senado,
        sigla_senado,
        partido_sigla,
        partido_nome
    FROM partidos_norm
    ORDER BY id_senado, id_camara DESC
),

partidos_senado AS (
    SELECT
        c.id_senado,
        c.sigla_senado,
        c.partido_sigla,
        c.partido_nome,
        v.data_criacao,
        v.data_extincao
    FROM partidos_canonico c
    JOIN partidos_vigencia v USING (id_senado)
),

-- Siglas reutilizadas (PL, PSD): desambigua pela vigência.
votos_com_partidos AS (
    SELECT
        t1.casa,
        t1.senador_id_nk,
        t1.votacao_id_fk,
        t2.id_senado                                            AS partido_id_senado,
        t2.partido_sigla                                        AS partido,
        COALESCE(t2.partido_nome, '{{ var("null_string") }}')   AS partido_nome,
        t1.data_votacao,
        t1.identificacao,
        t1.codigo_voto,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM votos_filtrados t1
    LEFT JOIN partidos_senado t2
        ON t2.sigla_senado = t1.sigla_partido
       AND t1.data_votacao BETWEEN t2.data_criacao AND t2.data_extincao
)

SELECT * FROM votos_com_partidos
