{{ config(
    tags=["politica"]
) }}


WITH
source AS (
    SELECT
        'API'                                AS origem,
        id,
        siglatipo,
        codtipo,
        numero,
        ano,
        ementa,
        dataapresentacao,
        keywords,
        statusproposicao_datahora            AS status_datahora,
        statusproposicao_sequencia           AS status_sequencia,
        statusproposicao_siglaorgao          AS status_siglaorgao,
        statusproposicao_regime              AS status_regime,
        statusproposicao_descricaotramitacao AS status_descricaotramitacao,
        statusproposicao_codtipotramitacao   AS status_codtipotramitacao,
        statusproposicao_descricaosituacao   AS status_descricaosituacao,
        statusproposicao_codsituacao         AS status_codsituacao,
        statusproposicao_despacho            AS status_despacho,
        statusproposicao_ambito              AS status_ambito,
        statusproposicao_apreciacao          AS status_apreciacao,
        statusproposicao_uriultimorelator    AS status_urirelator,
        uripropprincipal,
        uripropanterior,
        uripropposterior,
        loaded_at_utc
    FROM {{ source('camara','raw_camara_proposicao') }}
),

source_arquivo AS (
    SELECT
        'ARQUIVO'                        AS origem,
        id,
        siglatipo,
        codtipo,
        numero,
        ano,
        ementa,
        dataapresentacao,
        keywords,
        ultimostatus_data                AS status_datahora,
        ultimostatus_sequencia           AS status_sequencia,
        ultimostatus_siglaorgao          AS status_siglaorgao,
        ultimostatus_regime              AS status_regime,
        ultimostatus_descricaotramitacao AS status_descricaotramitacao,
        ultimostatus_idtipotramitacao    AS status_codtipotramitacao,
        ultimostatus_descricaosituacao   AS status_descricaosituacao,
        ultimostatus_idsituacao          AS status_codsituacao,
        ultimostatus_despacho            AS status_despacho,
        NULL::TEXT                       AS status_ambito,
        ultimostatus_apreciacao          AS status_apreciacao,
        ultimostatus_urirelator          AS status_urirelator,
        uripropprincipal,
        uripropanterior,
        uripropposterior,
        loaded_at_utc
    FROM {{ source('camara','arquivo_proposicoes') }}
),

source_unioned AS (
    SELECT * FROM source
    UNION ALL
    SELECT * FROM source_arquivo
),

-- O arquivo anual contém as proposições da API: vence o status mais recente e, no empate, a API, que traz o âmbito.
deduplicada AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY id
            ORDER BY status_datahora::TIMESTAMP DESC NULLS LAST, (origem = 'API') DESC
        ) AS rn,
        -- A API deixa vazios os vínculos que o arquivo preenche (ex.: principal de requerimentos).
        COALESCE(NULLIF(uripropprincipal, ''), MAX(NULLIF(uripropprincipal, '')) OVER (PARTITION BY id)) AS uri_principal,
        COALESCE(NULLIF(uripropanterior, ''), MAX(NULLIF(uripropanterior, '')) OVER (PARTITION BY id))   AS uri_anterior,
        COALESCE(NULLIF(uripropposterior, ''), MAX(NULLIF(uripropposterior, '')) OVER (PARTITION BY id)) AS uri_posterior
    FROM source_unioned
),

renamed AS (
    SELECT
        id::INT                                                   AS proposicao_id_nk,
        siglatipo                                                 AS sigla_tipo,
        codtipo::INT                                              AS codigo_tipo,
        numero::INT                                               AS numero,
        -- Pareceres, emendas e similares vêm com ano 0 no arquivo.
        NULLIF(ano::INT, 0)                                       AS ano,
        {{ clean_string('ementa', 'upper') }}                     AS ementa,
        dataapresentacao::TIMESTAMP::DATE                         AS data_apresentacao,
        {{ clean_string("keywords", "upper") }}                   AS palavras_chave,
        status_datahora::TIMESTAMP::DATE                          AS data_status,
        status_sequencia::INT                                     AS status_sequencia,
        status_siglaorgao                                         AS status_sigla_orgao,
        {{ clean_string("status_regime", "upper") }}              AS status_regime,
        {{ clean_string("status_descricaotramitacao", "upper") }} AS status_descricao_tramitacao,
        status_codtipotramitacao::INT                             AS status_codigo_tipo_tramitacao,
        {{ clean_string("status_descricaosituacao", "upper") }}   AS status_descricao_situacao,
        status_codsituacao::INT                                   AS status_codigo_situacao,
        {{ clean_string("status_despacho", "upper") }}            AS status_despacho,
        {{ clean_string("status_ambito", "upper") }}              AS status_ambito,
        {{ clean_string("status_apreciacao", "upper") }}          AS status_apreciacao,
        NULLIF(SPLIT_PART(status_urirelator, '/', 7), '')::INT    AS relator_id_fk,
        NULLIF(SPLIT_PART(uri_principal, '/', 7), '')::INT        AS proposicao_principal_id_fk,
        NULLIF(SPLIT_PART(uri_anterior, '/', 7), '')::INT         AS proposicao_anterior_id_fk,
        NULLIF(SPLIT_PART(uri_posterior, '/', 7), '')::INT        AS proposicao_posterior_id_fk,
        origem,
        loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ                       AS model_run_at
    FROM deduplicada
    WHERE rn = 1
)

SELECT * FROM renamed
