{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='processo_id_nk',
    on_schema_change='append_new_columns',
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
    {% if is_incremental() %}
        WHERE
            loaded_at_utc > (
                SELECT MAX(loaded_at_utc) FROM {{ this }}
                WHERE origem = 'API'
            )
    {% endif %}
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
    {% if is_incremental() %}
        WHERE
            loaded_at_utc > (
                SELECT MAX(loaded_at_utc) FROM {{ this }}
                WHERE origem = 'ARQUIVO'
            )
    {% endif %}
),

source_unioned AS (
    SELECT * FROM source
    UNION ALL
    SELECT * FROM source_arquivo
),

-- Só as linhas novas passam pela limpeza de texto.
limpas AS (
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
        loaded_at_utc
    FROM source_unioned
),

-- Na carga incremental, a versão já publicada dos processos que chegaram concorre com a nova.
candidatas AS (
    SELECT * FROM limpas
    {% if is_incremental() %}
        UNION ALL
        SELECT
            processo_id_nk,
            tramitando,
            autoria,
            codigo_materia,
            data_apresentacao,
            data_deliberacao,
            data_situacao_atual,
            sigla_tipo,
            identificacao,
            ementa,
            norma_gerada,
            objetivo,
            sigla_tipo_deliberacao,
            situacao_atual,
            tipo_conteudo,
            tipo_documento,
            origem,
            loaded_at_utc
        FROM {{ this }}
        WHERE processo_id_nk IN (SELECT processo_id_nk FROM limpas)
    {% endif %}
),

-- A listagem anual contém os processos da API: vence a situação mais recente e, no empate, a última carga.
ranqueada AS (
    SELECT
        processo_id_nk,
        origem,
        loaded_at_utc,
        ROW_NUMBER() OVER (
            PARTITION BY processo_id_nk
            ORDER BY data_situacao_atual DESC NULLS LAST, loaded_at_utc DESC
        ) AS rn
    FROM candidatas
)

SELECT
    c.processo_id_nk,
    c.tramitando,
    c.autoria,
    c.codigo_materia,
    c.data_apresentacao,
    c.data_deliberacao,
    c.data_situacao_atual,
    c.sigla_tipo,
    c.identificacao,
    c.ementa,
    c.norma_gerada,
    c.objetivo,
    c.sigla_tipo_deliberacao,
    c.situacao_atual,
    c.tipo_conteudo,
    c.tipo_documento,
    c.origem,
    c.loaded_at_utc,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM candidatas AS c
INNER JOIN ranqueada AS r
    ON
    c.processo_id_nk = r.processo_id_nk
    AND c.origem = r.origem
    AND c.loaded_at_utc = r.loaded_at_utc
WHERE r.rn = 1
