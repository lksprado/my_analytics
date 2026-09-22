{{ config(
    tags=["camara", "legislacao"]
) }}


WITH source AS (
    SELECT * FROM {{ source('camara','raw_camara_proposicao') }}
),

renamed AS (
    SELECT
        id::INT                                                             AS proposicao_id_nk,
        siglatipo                                                           AS sigla_tipo,
        codtipo                                                             AS codigo_tipo,
        numero::INT                                                         AS numero,
        ano::INT                                                            AS ano,
        {{ clean_string('ementa', 'upper') }}                               AS ementa,
        dataapresentacao::TIMESTAMP::DATE                                   AS data_apresentacao,
        {{ clean_string("keywords", "upper") }}                             AS palavras_chave,
        statusproposicao_datahora::TIMESTAMP::DATE                          AS data_status,
        statusproposicao_sequencia::INT                                     AS status_sequencia,
        statusproposicao_siglaorgao                                         AS status_sigla_orgao,
        {{ clean_string("statusproposicao_regime", "upper") }}              AS status_regime,
        {{ clean_string("statusproposicao_descricaotramitacao", "upper") }} AS status_descricao_tramitacao,
        statusproposicao_codtipotramitacao::INT                             AS status_codigo_tipo_tramitacao,
        {{ clean_string("statusproposicao_descricaosituacao", "upper") }}   AS status_descricao_situacao,
        statusproposicao_codsituacao::INT                                   AS status_codigo_situacao,
        {{ clean_string("statusproposicao_despacho", "upper") }}            AS status_despacho,
        {{ clean_string("statusproposicao_ambito", "upper") }}              AS status_ambito,
        {{ clean_string("statusproposicao_apreciacao", "upper") }}          AS status_apreciacao,
        loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ                                 AS model_run_at
    FROM source
)

SELECT * FROM renamed
