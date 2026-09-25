{{ config(
    tags=["politica"]
) }}

WITH
source AS (
    SELECT
        'API' AS origem,
        id,
        tramitando,
        autoria,
        codigomateria,
        dataapresentacao,
        datadeliberacao,
        datasituacaoatual,
        identificacao,
        ementa,
        normagerada,
        objetivo,
        siglatipodeliberacao,
        situacaoatual,
        tipoconteudo,
        tipodocumento,
        loaded_at_utc
    FROM {{ source('senado','raw_senado_processo') }}
),

source_arquivo AS (
    SELECT
        'ARQUIVO' AS origem,
        id,
        tramitando,
        autoria,
        codigomateria,
        dataapresentacao,
        datadeliberacao,
        datasituacaoatual,
        identificacao,
        ementa,
        normagerada,
        objetivo,
        siglatipodeliberacao,
        situacaoatual,
        tipoconteudo,
        tipodocumento,
        loaded_at_utc
    FROM {{ source('senado','processos') }}
),

source_unioned AS (
    SELECT * FROM source
    UNION ALL
    SELECT * FROM source_arquivo
),

-- A listagem anual contém os processos da API: vence a situação mais recente e, no empate, a última carga.
deduplicada AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY id
            ORDER BY datasituacaoatual::DATE DESC NULLS LAST, loaded_at_utc DESC
        ) AS rn
    FROM source_unioned
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
    {{ clean_string("ementa", "upper") }}       AS ementa,
    {{ clean_string("normagerada", "upper") }}  AS norma_gerada,
    {{ clean_string("objetivo","upper") }}      AS objetivo,
    siglatipodeliberacao                        AS sigla_tipo_deliberacao,
    {{ clean_string("situacaoatual","upper") }} AS situacao_atual,
    {{ clean_string("tipoconteudo","upper") }}  AS tipo_conteudo,
    {{ clean_string("tipodocumento","upper") }} AS tipo_documento,
    origem,
    loaded_at_utc,
    '{{ run_started_at }}'::TIMESTAMPTZ         AS model_run_at
FROM deduplicada
WHERE rn = 1
