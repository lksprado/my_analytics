{{ config(
    tags=["politica"]
) }}

WITH
consultas AS (
    SELECT
        identificacao,
        sk_proposicao,
        data_extracao,
        votos_sim,
        votos_nao,
        total_votos
    FROM {{ ref('fct_consultas_publicas') }}
),

-- Vale a última extração disponível: os votos da consulta se acumulam até ela fechar.
ultima AS (
    SELECT DISTINCT ON (identificacao)
        identificacao,
        sk_proposicao,
        data_extracao,
        votos_sim,
        votos_nao,
        total_votos
    FROM consultas
    ORDER BY identificacao ASC, data_extracao DESC
),

extracoes AS (
    SELECT
        identificacao,
        COUNT(*)           AS qt_extracoes,
        MIN(data_extracao) AS data_primeira_extracao
    FROM consultas
    GROUP BY identificacao
),

resultados AS (
    SELECT
        u.identificacao,
        u.sk_proposicao,
        p.tipo_proposicao,
        p.ementa,
        p.situacao_atual,
        p.fl_tramitando,
        p.codigo_deliberacao,
        p.data_deliberacao,
        u.votos_sim             AS votos_sim_ecidadania,
        u.votos_nao             AS votos_nao_ecidadania,
        u.total_votos           AS total_votos_ecidadania,
        e.qt_extracoes,
        e.data_primeira_extracao,
        u.data_extracao         AS data_ultima_extracao,
        CASE
            WHEN u.votos_sim > u.votos_nao THEN 'SIM'
            WHEN u.votos_nao > u.votos_sim THEN 'NAO'
            ELSE 'EMPATE'
        END                     AS resultado_consulta,
        d.resultado_legislativo AS resultado_votacao
    FROM ultima AS u
    INNER JOIN extracoes AS e
        ON u.identificacao = e.identificacao
    LEFT JOIN {{ ref('dim_proposicoes') }} AS p
        ON u.sk_proposicao = p.sk_proposicao
    LEFT JOIN {{ ref('stg_senado_tipos_decisao') }} AS d
        ON p.codigo_deliberacao = d.codigo_deliberacao
),

final AS (
    SELECT
        *,
        CASE
            WHEN resultado_consulta = 'SIM' AND resultado_votacao = 'APROVADA' THEN 1
            WHEN resultado_consulta = 'NAO' AND resultado_votacao = 'REJEITADA' THEN 1
            WHEN resultado_consulta IN ('SIM', 'NAO') AND resultado_votacao IN ('APROVADA', 'REJEITADA') THEN 0
        END                                 AS aderencia_consulta_publica,
        CASE
            WHEN sk_proposicao = '{{ var("null_key") }}' THEN 'MATERIA NAO ENCONTRADA NO SENADO'
            WHEN resultado_consulta = 'EMPATE' THEN 'EMPATE NA CONSULTA'
            WHEN codigo_deliberacao IS NULL THEN 'SEM DELIBERACAO'
            WHEN resultado_votacao NOT IN ('APROVADA', 'REJEITADA') OR resultado_votacao IS NULL THEN 'DELIBERACAO NAO BINARIA'
        END                                 AS motivo_aderencia_nula,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM resultados
)

SELECT * FROM final
