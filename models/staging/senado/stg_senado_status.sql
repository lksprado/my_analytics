{{ config(
    tags=["politica"]
) }}

WITH source AS (
    SELECT * FROM {{ source('senado','raw_senado_status') }}
),

renamed AS (
    SELECT
        id                                                                                      AS proposicao_id_nk,
        codigomateria                                                                           AS codigo_materia,
        identificacao,
        SPLIT_PART(identificacao, ' ', 1)                                                       AS sigla_proposicao,
        {{ clean_string("apelido", "upper") }}                                                  AS apelido,
        casaidentificadora                                                                      AS codigo_casa,
        CASE WHEN casaidentificadora = 'SF' THEN 'Senado Federal' ELSE 'Congresso Nacional' END AS casa,
        UPPER(enteidentificador)                                                                AS codigo_ente,
        {{ clean_string("ementa", "upper") }}                                                   AS ementa,
        {{ clean_string("tipodocumento", "upper") }}                                            AS tipo_proposicao,
        TO_DATE(dataapresentacao, 'YYYY-MM-DD')                                                 AS data_apresentacao,
        {{ clean_string("autoria", "upper") }}                                                  AS autoria,
        {{ clean_string("tramitando", "upper") }}                                               AS tramitando,
        TO_DATE(datadeliberacao, 'YYYY-MM-DD')                                                  AS data_deliberacao,
        siglatipodeliberacao                                                                    AS codigo_deliberacao,
        {{ clean_string("situacaoatual", "upper") }}                                            AS situacao_atual,
        TO_DATE(datasituacaoatual, 'YYYY-MM-DD')                                                AS data_situacao_atual,
        urldocumento                                                                            AS link_documento,
        {{ clean_string("objetivo", "upper") }}                                                 AS objetivo,
        {{ clean_string("normagerada", "upper") }}                                              AS norma_gerada,
        ultimainformacaoatualizada                                                              AS ultima_informacao_atualizada,
        loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ                                                     AS model_run_at
    FROM source
    WHERE id IS NOT NULL
)

SELECT * FROM renamed
