{{ config(
    tags=["politica"]
) }}

WITH
relacoes AS (
    SELECT DISTINCT
        proposicao_id_nk,
        proposicao_principal_id_fk AS proposicao_relacionada_id_nk,
        'PRINCIPAL'                AS tipo_relacao
    FROM {{ ref('stg_camara_proposicao') }}
    WHERE proposicao_principal_id_fk IS NOT NULL
    UNION
    SELECT DISTINCT
        proposicao_id_nk,
        proposicao_anterior_id_fk AS proposicao_relacionada_id_nk,
        'ANTERIOR'                AS tipo_relacao
    FROM {{ ref('stg_camara_proposicao') }}
    WHERE proposicao_anterior_id_fk IS NOT NULL
    UNION
    SELECT DISTINCT
        proposicao_id_nk,
        proposicao_posterior_id_fk AS proposicao_relacionada_id_nk,
        'POSTERIOR'                AS tipo_relacao
    FROM {{ ref('stg_camara_proposicao') }}
    WHERE proposicao_posterior_id_fk IS NOT NULL
),

final AS (
    SELECT
        p.sk_proposicao,
        COALESCE(r2.sk_proposicao, '{{ var("null_key") }}') AS sk_proposicao_relacionada,
        r.proposicao_relacionada_id_nk,
        r.tipo_relacao,
        '{{ run_started_at }}'::TIMESTAMPTZ                 AS model_run_at
    FROM relacoes AS r
    INNER JOIN {{ ref('dim_proposicoes') }} AS p
        ON p.casa = 'CAMARA' AND r.proposicao_id_nk = p.proposicao_id_nk
    LEFT JOIN {{ ref('dim_proposicoes') }} AS r2
        ON r2.casa = 'CAMARA' AND r.proposicao_relacionada_id_nk = r2.proposicao_id_nk
)

SELECT * FROM final
