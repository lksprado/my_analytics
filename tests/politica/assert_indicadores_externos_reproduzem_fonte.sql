{{ config(tags=["politica"]) }}

-- A versão vigente reproduz sem alteração o valor publicado pela fonte.
WITH
vigentes AS (
    SELECT
        f.sk_parlamentar,
        i.fonte,
        i.indicador,
        f.periodo_inicio,
        f.valor_original
    FROM {{ ref('fct_indicadores_externos') }} AS f
    INNER JOIN {{ ref('dim_indicador_externo') }} AS i
        ON f.sk_indicador_externo = i.sk_indicador_externo
    WHERE f.fl_versao_vigente = 1
        AND f.sk_parlamentar <> '{{ var("null_key") }}'
),

radar AS (
    SELECT
        r.sk_parlamentar,
        MAKE_DATE(r.ano::INT, (r.trimestre::INT - 1) * 3 + 1, 1) AS periodo_inicio,
        r.governismo_pct_radar
    FROM {{ ref('fct_radarcongresso_governismo_trimestre') }} AS r
    WHERE r.sk_parlamentar <> '{{ var("null_key") }}'
),

ranking AS (
    SELECT
        sk_parlamentar,
        pontuacao_geral
    FROM {{ ref('fct_ranking_politicos') }}
    WHERE sk_parlamentar <> '{{ var("null_key") }}'
        AND pontuacao_geral IS NOT NULL
)

SELECT
    r.sk_parlamentar,
    'RADAR'                         AS fonte,
    r.governismo_pct_radar::NUMERIC AS esperado,
    v.valor_original                AS obtido
FROM radar AS r
LEFT JOIN vigentes AS v
    ON r.sk_parlamentar = v.sk_parlamentar
    AND v.indicador = 'GOVERNISMO TRIMESTRAL'
    AND r.periodo_inicio = v.periodo_inicio
WHERE v.valor_original IS DISTINCT FROM r.governismo_pct_radar::NUMERIC
UNION ALL
SELECT
    k.sk_parlamentar,
    'RANKING'                  AS fonte,
    k.pontuacao_geral::NUMERIC AS esperado,
    v.valor_original           AS obtido
FROM ranking AS k
LEFT JOIN vigentes AS v
    ON k.sk_parlamentar = v.sk_parlamentar
    AND v.indicador = 'PONTUACAO GERAL'
WHERE v.valor_original IS DISTINCT FROM k.pontuacao_geral::NUMERIC
