{{ config(
    tags=["senado", "votacoes"]
) }}

WITH source AS (
    SELECT * FROM {{ source('senado','raw_senado_votacoes') }}
)

SELECT
    codigomateria::INT                  AS codigo_materia,
    codigosessao::INT                   AS codigo_sessao,
    codigosessaolegislativa::BIGINT     AS codigo_sessao_legislativa,
    codigosessaovotacao::BIGINT         AS codigo_sessao_votacao,
    codigovotacaosve::BIGINT            AS votacao_id_nk,
    idprocesso::INT                     AS processo_id_nk,
    identificacao,
    numero,
    numerosessao::INT                   AS numero_sessao,
    sigla,
    descricaovotacao                    AS descricao_votacao,
    siglatiposessao                     AS sigla_tipo_sessao,
    totalvotosabstencao::INT            AS total_votos_abstencao,
    totalvotosnao::INT                  AS total_votos_contra,
    totalvotossim::INT                  AS total_votos_favor,
    TO_DATE(datasessao, 'YYYY-MM-DD')   AS data_votacao,
    CASE
        WHEN resultadovotacao = 'A' THEN 'APROVADO'
        WHEN resultadovotacao = 'R' THEN 'REPROVADO'
        WHEN resultadovotacao = 'P' THEN 'PREJUDICADO'
        WHEN resultadovotacao = 'E' THEN 'EMPATE'
    END                                 AS resultado_votacao,
    CASE
        WHEN votacaosecreta = 'N' THEN 'NAO'
        WHEN votacaosecreta = 'S' THEN 'SIM'
    END                                 AS votacao_secreta,
    CASE
        WHEN resultadovotacao = 'A' THEN 1
        WHEN resultadovotacao IN ('R', 'E', 'P') THEN 0
    END                                 AS aprovado,
    loaded_at_utc,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM source
