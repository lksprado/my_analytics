{{ config(
    tags=["politica"]
) }}

WITH
temas_proprios AS (
    SELECT
        proposicao_id_nk::INT AS proposicao_id_nk,
        codigo_tema,
        MAX(relevancia)       AS relevancia
    FROM {{ ref('stg_camara_proposicao_tema') }}
    WHERE codigo_tema IS NOT NULL
    GROUP BY proposicao_id_nk::INT, codigo_tema
),

-- Requerimentos e destaques não têm tema: herdam os da proposição principal, um nível só.
temas_herdados AS (
    SELECT
        p.proposicao_id_nk,
        tp.codigo_tema,
        tp.relevancia
    FROM {{ ref('stg_camara_proposicao') }} AS p
    INNER JOIN temas_proprios AS tp
        ON p.proposicao_principal_id_fk = tp.proposicao_id_nk
    WHERE
        NOT EXISTS (
            SELECT 1
            FROM temas_proprios AS proprio
            WHERE proprio.proposicao_id_nk = p.proposicao_id_nk
        )
),

temas_proposicao AS (
    SELECT
        proposicao_id_nk,
        codigo_tema,
        relevancia,
        'PROPRIO' AS origem_tema
    FROM temas_proprios
    UNION ALL
    SELECT
        proposicao_id_nk,
        codigo_tema,
        relevancia,
        'HERDADO' AS origem_tema
    FROM temas_herdados
),

final AS (
    SELECT
        p.sk_proposicao,
        t.sk_tema,
        tp.relevancia,
        tp.origem_tema,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM temas_proposicao AS tp
    INNER JOIN {{ ref('dim_proposicoes') }} AS p
        ON p.casa = 'CAMARA' AND tp.proposicao_id_nk = p.proposicao_id_nk
    INNER JOIN {{ ref('dim_tema') }} AS t
        ON tp.codigo_tema = t.codigo_tema
)

SELECT * FROM final
