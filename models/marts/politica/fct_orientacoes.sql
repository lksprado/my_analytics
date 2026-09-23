{{ config(
    tags=["politica"]
) }}

WITH
orientacoes AS (
    SELECT * FROM {{ ref('int_orientacoes_unificadas') }}
),

votacoes AS (
    SELECT
        sk_votacao,
        casa,
        votacao_id_nk,
        sk_data
    FROM {{ ref('fct_votacoes') }}
),

partidos AS (
    SELECT
        sk_partido,
        partido_id_nk
    FROM {{ ref('dim_partidos') }}
),

final AS (
    SELECT
        COALESCE(v.sk_votacao, '{{ var("null_key") }}')                           AS sk_votacao,
        -- A orientação órfã do Senado ainda traz a própria data da votação.
        COALESCE(v.sk_data, CAST(TO_CHAR(o.data_votacao, 'YYYYMMDD') AS INTEGER)) AS sk_data,
        -- Só lideranças partidárias têm entidade; Governo, blocos e federações ficam em null_key.
        COALESCE(p.sk_partido, '{{ var("null_key") }}')                           AS sk_partido,
        o.casa,
        o.votacao_id_nk,
        o.sigla_lideranca,
        o.tipo_lideranca,
        o.orientacao_voto,
        '{{ run_started_at }}'::TIMESTAMPTZ                                       AS model_run_at
    FROM orientacoes AS o
    LEFT JOIN votacoes AS v
        ON o.casa = v.casa AND o.votacao_id_nk = v.votacao_id_nk
    LEFT JOIN partidos AS p
        ON o.partido_id_senado = p.partido_id_nk
)

SELECT * FROM final
