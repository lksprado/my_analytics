{{ config(
    tags=["politica"]
) }}

WITH
votacoes AS (
    SELECT
        casa,
        votacao_id_nk,
        data_votacao,
        sigla_orgao,
        descricao,
        proposicao_id_fk AS proposicao_id_nk,
        aprovado,
        0                AS fl_secreta
    FROM {{ ref('int_votacoes_camara_deduplicadas') }}
    UNION ALL
    -- A extração do Senado só traz votações do Plenário.
    SELECT
        casa,
        votacao_id_nk::TEXT,
        data_votacao,
        'PLEN',
        descricao,
        processo_id_nk,
        aprovado,
        fl_secreta
    FROM {{ ref('int_votacoes_senado_filtradas') }}
)

SELECT
    *,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM votacoes
