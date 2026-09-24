{{ config(
    tags=["politica"]
) }}

WITH
liderancas AS (
    SELECT
        casa,
        sigla_lideranca,
        partido_id_senado,
        MIN(data_votacao) AS primeira_orientacao,
        MAX(data_votacao) AS ultima_orientacao
    FROM {{ ref('int_orientacoes_unificadas') }}
    GROUP BY casa, sigla_lideranca, partido_id_senado
),

membros AS (
    SELECT
        casa,
        sigla_bancada,
        STRING_AGG(DISTINCT partido, ', ' ORDER BY partido) AS partidos_membros
    FROM {{ ref('seed_bancadas_composicao') }}
    GROUP BY casa, sigla_bancada
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['l.casa', 'l.sigla_lideranca', 'l.partido_id_senado']) }} AS sk_bancada,
        l.casa,
        l.sigla_lideranca                                                                              AS sigla_bancada,
        -- Na Câmara, liderança que não é partido nem tem prefixo é bloco com as siglas coladas (PMDBPTC).
        CASE
            WHEN l.partido_id_senado IS NOT NULL THEN 'PARTIDO'
            WHEN l.sigla_lideranca IN ('GOVERNO', 'MAIORIA', 'MINORIA', 'OPOSICAO') THEN l.sigla_lideranca
            WHEN l.sigla_lideranca LIKE 'FDR %' THEN 'FEDERACAO'
            WHEN l.sigla_lideranca LIKE 'BL %' OR l.sigla_lideranca LIKE 'BLOCO%' THEN 'BLOCO'
            WHEN l.sigla_lideranca ~ 'FEM' THEN 'BANCADA TEMATICA'
            WHEN l.casa = 'CAMARA' THEN 'BLOCO'
            ELSE 'OUTRA'
        END                                                                                            AS tipo_bancada,
        COALESCE(p.sk_partido, '{{ var("null_key") }}')                                                AS sk_partido,
        m.partidos_membros,
        l.primeira_orientacao,
        l.ultima_orientacao,
        '{{ run_started_at }}'::TIMESTAMPTZ                                                            AS model_run_at
    FROM liderancas AS l
    LEFT JOIN {{ ref('dim_partidos') }} AS p
        ON l.partido_id_senado = p.partido_id_nk
    LEFT JOIN membros AS m
        ON l.casa = m.casa AND l.sigla_lideranca = m.sigla_bancada
)

SELECT * FROM final
UNION ALL
{{ dummy_row([
    ['sk_bancada', 'sk'],
    ['casa', 'text'],
    ['sigla_bancada', 'text'],
    ['tipo_bancada', 'text'],
    ['sk_partido', 'sk'],
    ['partidos_membros', 'null::text'],
    ['primeira_orientacao', 'null::date'],
    ['ultima_orientacao', 'null::date'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
