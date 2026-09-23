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
        -- Sobram só duplicatas exatas da origem; a ordem apenas torna a escolha estável.
        ROW_NUMBER() OVER (
            PARTITION BY votacao_id_nk
            ORDER BY datahora_votacao DESC NULLS LAST, loaded_at_utc DESC
        ) AS rn
    FROM camara_votacoes
),

final AS (
    SELECT
        casa,
        votacao_id_nk,
        data_votacao,
        sigla_orgao,
        descricao,
        proposicao_id_fk,
        aprovado,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM dedup
    WHERE rn = 1
    ORDER BY data_votacao DESC
)

SELECT * FROM final
