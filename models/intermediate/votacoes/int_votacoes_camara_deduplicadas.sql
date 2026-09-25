{{ config(
    tags=["politica"]
) }}


WITH
camara_votacoes AS (
    SELECT
        *,
        'CAMARA' AS casa
    FROM {{ ref('stg_camara_votacoes') }}
),

dedup AS (
    SELECT
        *,
        -- Só há duplicatas exatas (mesma data): a data na partição deixa o filtro por período descer à tabela.
        ROW_NUMBER() OVER (
            PARTITION BY votacao_id_nk, data_votacao
            ORDER BY datahora_votacao DESC NULLS LAST, loaded_at_utc DESC
        ) AS rn
    FROM camara_votacoes
),

final AS (
    SELECT
        casa,
        votacao_id_nk,
        sessao_id,
        data_votacao,
        sigla_orgao,
        descricao,
        proposicao_id_fk,
        aprovado,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM dedup
    WHERE rn = 1
)

SELECT * FROM final
