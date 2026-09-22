{{ config(
    tags=["senado", "legislacao"]
) }}


WITH source AS (
    SELECT * FROM {{ ref('seed_senado_tipos_decisao') }}
),

renamed AS (
    SELECT
        sigla                               AS codigo_deliberacao,
        descricao                           AS descricao_deliberacao,
        CASE
            WHEN sigla = 'APROVADA_NO_PLENARIO' THEN 'FAVOR'
            WHEN sigla = 'APROVADA_EM_COMISSAO_TERMINATIVA' THEN 'FAVOR'
            WHEN sigla = 'APROVADA_PARCIALMENTE' THEN 'FAVOR'
            WHEN sigla = 'APROVADO_CDIR' THEN 'FAVOR'
            WHEN sigla = 'APROVADO_NA_INTEGRA' THEN 'FAVOR'
            WHEN sigla = 'APROVADO_PLV' THEN 'FAVOR'
            WHEN sigla = 'APROVADO_PLV_COM_EMENDAS' THEN 'FAVOR'
            WHEN sigla = 'DEFERIDO_CDIR' THEN 'FAVOR'
            WHEN sigla = 'DEFERIDO_PRESIDENCIA_ART_101_RISF' THEN 'FAVOR'
            WHEN sigla = 'DEFERIDO_PRESIDENCIA_ART_214_RISF' THEN 'FAVOR'
            WHEN sigla = 'DEFERIDO_PRESIDENCIA_ART_215_RISF' THEN 'FAVOR'
            WHEN sigla = 'DEFERIDO_PRESIDENCIA_ART_41_RISF' THEN 'FAVOR'
            WHEN sigla = 'PUBLICADO' THEN 'FAVOR'
            WHEN sigla = 'REEDITADA' THEN 'FAVOR'
            WHEN sigla = 'TRANSF_IND' THEN 'FAVOR'
            WHEN sigla = 'TRANSF_PROJ_LEI_SEN' THEN 'FAVOR'
            WHEN sigla = 'TRANSF_PROJ_RES_SEN' THEN 'FAVOR'
            WHEN sigla = 'TRANSF_PROPOSTA_DE_EC' THEN 'FAVOR'
            WHEN sigla = 'ARQUIVADO_FIM_LEGISLATURA' THEN 'CONTRA'
            WHEN sigla = 'DEVOLVIDO_CD_ACAO_JUD' THEN 'CONTRA'
            WHEN sigla = 'IMPUGNADO_PRESIDENCIA' THEN 'CONTRA'
            WHEN sigla = 'INADIMITIDA_URGENCIA' THEN 'CONTRA'
            WHEN sigla = 'PERDA_EFICACIA' THEN 'CONTRA'
            WHEN sigla = 'PREJUDICADO' THEN 'CONTRA'
            WHEN sigla = 'REJEITADO_COMISSAO_NAO_TERM' THEN 'CONTRA'
            WHEN sigla = 'REJEITADO_COMISSAO_TERM' THEN 'CONTRA'
            WHEN sigla = 'REJEITADO_INCONSTICIONALIDADE_CCJ' THEN 'CONTRA'
            WHEN sigla = 'REJEITADO_PLENARIO' THEN 'CONTRA'
            WHEN sigla = 'REJEITADO_PLENARIO_CD' THEN 'CONTRA'
            WHEN sigla = 'RETIRADA_DE_ASSINATURA' THEN 'CONTRA'
            WHEN sigla = 'RETIRADO_PELO_AUTOR' THEN 'CONTRA'
            WHEN sigla = 'REVOGADO' THEN 'CONTRA'
            WHEN sigla = 'SEM_EFICACIA' THEN 'CONTRA'
            WHEN sigla = 'CONHECIDA' THEN 'NEUTRO'
            WHEN sigla = 'PARA_PUBLICACAO' THEN 'NEUTRO'
            WHEN sigla = 'REAUTUADO' THEN 'NEUTRO'
            ELSE NULL
        END                                 AS tipo_deliberacao,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM source
)

SELECT * FROM renamed
