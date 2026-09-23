{{ config(
    tags=["politica"]
) }}

WITH source AS (
    SELECT * FROM {{ source('senado','raw_senado_processo') }}
)

SELECT
    id::INT                                     AS processo_id_nk,
    {{ clean_string('tramitando', 'upper') }}   AS tramitando,
    {{ clean_string('autoria', 'upper') }}      AS autoria,
    codigomateria::INT                          AS codigo_materia,
    dataapresentacao::DATE                      AS data_apresentacao,
    datadeliberacao::DATE                       AS data_deliberacao,
    datasituacaoatual::DATE                     AS data_situacao_atual,
    NULLIF(
        REGEXP_REPLACE(
            COALESCE(identificacao::TEXT, ''),
            '[^[:alpha:]]',
            '',
            'g'
        ),
        ''
    )                                           AS sigla_tipo,
    identificacao,
    {{ clean_string("normagerada", "upper") }}  AS norma_gerada,
    {{ clean_string("objetivo","upper") }}      AS objetivo,
    siglatipodeliberacao                        AS sigla_tipo_deliberacao,
    {{ clean_string("situacaoatual","upper") }} AS situacao_atual,
    {{ clean_string("tipoconteudo","upper") }}  AS tipo_conteudo,
    {{ clean_string("tipodocumento","upper") }} AS tipo_documento,
    loaded_at_utc,
    '{{ run_started_at }}'::TIMESTAMPTZ         AS model_run_at
FROM source
