{{ config(
    tags=["politica"]
) }}

WITH
orientacoes AS (
    SELECT
        casa,
        votacao_id_fk       AS votacao_id_nk,
        NULL::DATE          AS data_votacao,
        tipo_lideranca,
        sigla_partido_bloco AS sigla_lideranca,
        orientacao_voto
    FROM {{ ref('int_orientacoes_camara_corrigidas') }}
    UNION ALL
    SELECT
        casa,
        votacao_id_fk::TEXT,
        data_votacao,
        '{{ var("null_string") }}',
        partido,
        orientacao_voto
    FROM {{ ref('int_orientacoes_senado_filtradas') }}
),

-- A orientação da Câmara não traz data; ela vem da votação, para desambiguar sigla reutilizada.
com_data AS (
    SELECT
        o.casa,
        o.votacao_id_nk,
        COALESCE(o.data_votacao, v.data_votacao) AS data_votacao,
        o.tipo_lideranca,
        o.sigla_lideranca,
        o.orientacao_voto
    FROM orientacoes AS o
    LEFT JOIN {{ ref('int_votacoes_unificadas') }} AS v
        ON o.casa = v.casa AND o.votacao_id_nk = v.votacao_id_nk
),

-- A sigla vale para a entidade vigente na data; nas transições (fusão, rebrand) a origem ainda
-- usa a sigla antiga por alguns dias, e fica a entidade mais próxima no tempo.
com_partido AS (
    SELECT DISTINCT ON (o.casa, o.votacao_id_nk, o.sigla_lideranca)
        o.*,
        p.partido_id_senado
    FROM com_data AS o
    LEFT JOIN {{ ref('int_partidos_siglas') }} AS p
        ON o.sigla_lideranca = p.sigla
    ORDER BY
        o.casa,
        o.votacao_id_nk,
        o.sigla_lideranca,
        CASE
            WHEN o.data_votacao BETWEEN p.inicio AND p.fim THEN 0
            WHEN o.data_votacao < p.inicio THEN p.inicio - o.data_votacao
            ELSE o.data_votacao - p.fim
        END
)

SELECT
    *,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM com_partido
