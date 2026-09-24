{{ config(
    tags=["politica"]
) }}

WITH
temas_proposicao AS (
    SELECT
        proposicao_id_nk::INT AS proposicao_id_nk,
        codigo_tema,
        MAX(relevancia)       AS relevancia
    FROM {{ ref('stg_camara_proposicao_tema') }}
    WHERE codigo_tema IS NOT NULL
    GROUP BY proposicao_id_nk::INT, codigo_tema
),

final AS (
    SELECT
        p.sk_proposicao,
        t.sk_tema,
        tp.relevancia,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM temas_proposicao AS tp
    INNER JOIN {{ ref('dim_proposicoes') }} AS p
        ON p.casa = 'CAMARA' AND tp.proposicao_id_nk = p.proposicao_id_nk
    INNER JOIN {{ ref('dim_tema') }} AS t
        ON tp.codigo_tema = t.codigo_tema
)

SELECT * FROM final
