{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='proposicao_id_nk',
    on_schema_change='append_new_columns',
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

-- Só as linhas novas passam pela limpeza de texto, que é o custo do modelo.
limpas AS (
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
        NULLIF(SPLIT_PART(uripropprincipal, '/', 7), '')::INT     AS proposicao_principal_id_fk,
        NULLIF(SPLIT_PART(uripropanterior, '/', 7), '')::INT      AS proposicao_anterior_id_fk,
        NULLIF(SPLIT_PART(uripropposterior, '/', 7), '')::INT     AS proposicao_posterior_id_fk,
        origem,
        loaded_at_utc
    FROM source_unioned
),

-- Na carga incremental, a versão já publicada das proposições que chegaram concorre com a nova.
candidatas AS (
    SELECT * FROM limpas
    {% if is_incremental() %}
        UNION ALL
        SELECT
            proposicao_id_nk,
            sigla_tipo,
            codigo_tipo,
            numero,
            ano,
            ementa,
            data_apresentacao,
            palavras_chave,
            data_status,
            status_sequencia,
            status_sigla_orgao,
            status_regime,
            status_descricao_tramitacao,
            status_codigo_tipo_tramitacao,
            status_descricao_situacao,
            status_codigo_situacao,
            status_despacho,
            status_ambito,
            status_apreciacao,
            relator_id_fk,
            proposicao_principal_id_fk,
            proposicao_anterior_id_fk,
            proposicao_posterior_id_fk,
            origem,
            loaded_at_utc
        FROM {{ this }}
        WHERE proposicao_id_nk IN (SELECT proposicao_id_nk FROM limpas)
    {% endif %}
),

-- O arquivo anual contém as proposições da API: vence o status mais recente e, no empate, a API, que traz o âmbito.
-- A escolha roda só sobre as colunas estreitas; ordenar a linha inteira com a ementa estoura a memória.
ranqueada AS (
    SELECT
        proposicao_id_nk,
        origem,
        loaded_at_utc,
        ROW_NUMBER() OVER (
            PARTITION BY proposicao_id_nk
            ORDER BY data_status DESC NULLS LAST, (origem = 'API') DESC, loaded_at_utc DESC
        ) AS rn,
        -- A API deixa vazios os vínculos que o arquivo preenche (ex.: principal de requerimentos).
        MAX(proposicao_principal_id_fk) OVER (PARTITION BY proposicao_id_nk) AS principal_qualquer,
        MAX(proposicao_anterior_id_fk) OVER (PARTITION BY proposicao_id_nk)  AS anterior_qualquer,
        MAX(proposicao_posterior_id_fk) OVER (PARTITION BY proposicao_id_nk) AS posterior_qualquer
    FROM candidatas
),

final AS (
    SELECT
        c.proposicao_id_nk,
        c.sigla_tipo,
        c.codigo_tipo,
        c.numero,
        c.ano,
        c.ementa,
        c.data_apresentacao,
        c.palavras_chave,
        c.data_status,
        c.status_sequencia,
        c.status_sigla_orgao,
        c.status_regime,
        c.status_descricao_tramitacao,
        c.status_codigo_tipo_tramitacao,
        c.status_descricao_situacao,
        c.status_codigo_situacao,
        c.status_despacho,
        c.status_ambito,
        c.status_apreciacao,
        c.relator_id_fk,
        COALESCE(c.proposicao_principal_id_fk, r.principal_qualquer) AS proposicao_principal_id_fk,
        COALESCE(c.proposicao_anterior_id_fk, r.anterior_qualquer)   AS proposicao_anterior_id_fk,
        COALESCE(c.proposicao_posterior_id_fk, r.posterior_qualquer) AS proposicao_posterior_id_fk,
        c.origem,
        c.loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ                          AS model_run_at
    FROM candidatas AS c
    INNER JOIN ranqueada AS r
        ON
        c.proposicao_id_nk = r.proposicao_id_nk
        AND c.origem = r.origem
        AND c.loaded_at_utc = r.loaded_at_utc
    WHERE r.rn = 1
)

SELECT * FROM final
