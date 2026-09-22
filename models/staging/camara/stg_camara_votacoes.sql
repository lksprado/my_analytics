{{ config(
    tags=["camara", "votacoes"]
) }}


WITH source AS (
    SELECT * FROM {{ source('camara','raw_camara_votacoes') }}
),

renamed AS (
    SELECT
        {{ clean_integer("id") }}::BIGINT            AS votacao_id_nk,
        data::DATE                                   AS data_votacao,
        datahoraregistro::TIMESTAMP                  AS datahora_votacao,
        siglaorgao                                   AS sigla_orgao,
        proposicaoobjeto                             AS proposicao_objeto,
        {{ clean_string("descricao", "upper") }}     AS descricao,
        id_proposicao::INT                           AS proposicao_id_fk,
        aprovacao::INT                               AS aprovado,
        loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ          AS model_run_at
    FROM source
)

SELECT * FROM renamed
