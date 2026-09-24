{{ config(
    tags=["politica"]
) }}

WITH
consultas AS (
    SELECT
        identificacao,
        data_extracao,
        votos_sim,
        votos_nao,
        total_votos
    FROM {{ ref('stg_ecidadania_votacoes') }}
),

-- A consulta pública do e-Cidadania é sobre matérias do Senado; a identificação casa com o processo.
materias AS (
    SELECT DISTINCT ON (identificacao)
        identificacao,
        sk_proposicao
    FROM {{ ref('dim_proposicoes') }}
    WHERE casa = 'SENADO'
        AND identificacao IS NOT NULL
    ORDER BY identificacao ASC, data_proposicao DESC NULLS LAST
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['c.identificacao', 'c.data_extracao']) }} AS sk_consulta,
        COALESCE(m.sk_proposicao, '{{ var("null_key") }}')                             AS sk_proposicao,
        CAST(TO_CHAR(c.data_extracao, 'YYYYMMDD') AS INTEGER)                          AS sk_data,
        c.identificacao,
        c.data_extracao,
        c.votos_sim,
        c.votos_nao,
        c.total_votos,
        '{{ run_started_at }}'::TIMESTAMPTZ                                            AS model_run_at
    FROM consultas AS c
    LEFT JOIN materias AS m
        ON c.identificacao = m.identificacao
)

SELECT * FROM final
