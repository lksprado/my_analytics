{{ config(
    tags=["politica"]
) }}

WITH source AS (
    SELECT * FROM {{ source('senado','raw_senado_votos_senadores') }}
)

SELECT
    codigomateria::INT                                     AS codigo_materia,
    codigosessao::INT                                      AS codigo_sessao,
    codigosessaolegislativa::BIGINT                        AS codigo_sessao_legislativa,
    codigosessaovotacao::BIGINT                            AS votacao_id_fk,
    codigovotacaosve::INT                                  AS votacao_sve_id,
    TO_DATE(datasessao, 'YYYY-MM-DD')                      AS data_votacao,
    idprocesso::INT                                        AS processo_id_nk,
    identificacao,
    numero,
    numerosessao::INT                                      AS numero_sessao,
    sigla,
    siglatiposessao                                        AS sigla_tipo_sessao,
    codigoparlamentar::BIGINT                              AS senador_id_nk,
    {{ clean_string("descricaovotoparlamentar","upper") }} AS descricao_voto,
    {{ clean_string("siglapartidoparlamentar","upper") }}  AS sigla_partido,
    {{ clean_string("siglavotoparlamentar","upper") }}     AS sigla_voto,
    loaded_at_utc,
    '{{ run_started_at }}'::TIMESTAMPTZ                    AS model_run_at
FROM source
