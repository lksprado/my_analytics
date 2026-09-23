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
)

SELECT
    *,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM orientacoes
