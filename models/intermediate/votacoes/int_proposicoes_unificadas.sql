{{ config(
    tags=["politica"]
) }}

WITH
camara_proposicoes AS (
    SELECT
        'CAMARA'                               AS casa,
        proposicao_id_nk                       AS id,
        {{ clean_string ("t2.nome","upper") }} AS tipo_proposicao,
        data_apresentacao                      AS data_proposicao,
        t1.sigla_tipo || ' ' || t1.numero || '/' || t1.ano AS identificacao,
        t1.ementa,
        t1.status_descricao_situacao           AS situacao_atual,
        NULLIF(t1.status_regime, '.')          AS regime,
        NULL                                   AS autoria,
        NULL                                   AS norma_gerada
    FROM {{ ref('stg_camara_proposicao') }} AS t1
    LEFT JOIN {{ ref('seed_camara_tipos_proposicao') }} AS t2
        ON t1.codigo_tipo = t2.cod
),

senado_proposicoes AS (
    SELECT
        'SENADO'                                    AS casa,
        processo_id_nk                              AS id,
        {{ clean_string ("t2.descricao","upper") }} AS tipo_proposicao,
        data_apresentacao                           AS data_proposicao,
        t1.identificacao,
        NULL                                        AS ementa,
        t1.situacao_atual,
        NULL                                        AS regime,
        t1.autoria,
        t1.norma_gerada
    FROM {{ ref('stg_senado_processo') }} AS t1
    LEFT JOIN {{ ref('seed_senado_tipos_projetos') }} AS t2
        ON t1.sigla_tipo = t2.sigla
),

proposicoes AS (
    SELECT * FROM camara_proposicoes
    UNION ALL
    SELECT * FROM senado_proposicoes
),

final AS (
    SELECT
        casa,
        id                                                    AS proposicao_id_nk,
        COALESCE(tipo_proposicao, '{{ var("null_string") }}')  AS tipo_proposicao,
        data_proposicao,
        identificacao,
        ementa,
        situacao_atual,
        regime,
        autoria,
        norma_gerada
    FROM proposicoes
),

-- A origem repete (casa, id) com linhas parciais: vence a data mais recente e o tipo válido.
deduplicada AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY casa, proposicao_id_nk
            ORDER BY
                data_proposicao DESC NULLS LAST,
                (tipo_proposicao <> '{{ var("null_string") }}') DESC
        ) AS rn
    FROM final
)

SELECT
    casa,
    proposicao_id_nk,
    tipo_proposicao,
    data_proposicao,
    identificacao,
    ementa,
    situacao_atual,
    regime,
    autoria,
    norma_gerada,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM deduplicada
WHERE rn = 1
