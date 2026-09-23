{{ config(
    tags=["politica"]
) }}

WITH
presidentes AS (
    SELECT
        presidente,
        mandato,
        inicio::DATE AS inicio,
        fim::DATE    AS fim
    FROM {{ ref('seed_executivo_presidente') }}
),

legislaturas AS (
    SELECT
        legislatura::INT AS legislatura,
        inicio::DATE     AS inicio,
        fim::DATE        AS fim
    FROM {{ ref('seed_legislaturas') }}
),

orientacao_governo AS (
    SELECT
        sk_votacao,
        orientacao_voto
    FROM {{ ref('dim_orientacao_votacoes') }}
    WHERE sigla_partido_bloco = 'GOVERNO'
),

-- O grão é a votação com voto nominal registrado: 6.359 das 191.317 de dim_votacoes.
placar AS (
    SELECT
        sk_votacao,
        COUNT(*)                                   AS qt_votantes,
        COUNT(*) FILTER (WHERE voto = 'SIM')       AS qt_votos_sim,
        COUNT(*) FILTER (WHERE voto = 'NAO')       AS qt_votos_nao,
        COUNT(*) FILTER (WHERE voto = 'OBSTRUCAO') AS qt_obstrucao,
        COUNT(DISTINCT partido)                    AS qt_partidos
    FROM {{ ref('fct_votos') }}
    GROUP BY sk_votacao
),

votacoes AS (
    SELECT
        t1.sk_votacao,
        t1.votacao_id_nk,
        t1.casa,
        t1.data_votacao,
        t1.aprovado,
        t2.proposicao_id_nk,
        t2.tipo_proposicao,
        t2.data_proposicao
    FROM {{ ref('dim_votacoes') }} AS t1
    LEFT JOIN {{ ref('dim_proposicoes') }} AS t2
        ON t1.sk_proposicao = t2.sk_proposicao
    WHERE t1.sk_votacao <> '{{ var("null_key") }}'
),

-- A seed encosta o fim de um mandato no início do seguinte, então um BETWEEN duplicaria as
-- votações de 2016-08-31 e de 2019-01-01.
presidente_da_data AS (
    SELECT DISTINCT ON (t1.sk_votacao)
        t1.sk_votacao,
        t2.presidente,
        t2.mandato
    FROM votacoes AS t1
    INNER JOIN presidentes AS t2
        ON t1.data_votacao >= t2.inicio AND t1.data_votacao <= t2.fim
    ORDER BY t1.sk_votacao ASC, t2.inicio DESC
),

final AS (
    SELECT
        t1.sk_votacao,
        t2.votacao_id_nk,
        t2.casa,
        t2.data_votacao,
        EXTRACT(YEAR FROM t2.data_votacao)::INT
            AS ano,
        EXTRACT(QUARTER FROM t2.data_votacao)::INT
            AS trimestre,
        t3.legislatura,
        t4.presidente,
        t4.mandato,
        t2.tipo_proposicao,
        t2.proposicao_id_nk,
        t2.data_proposicao,
        t2.aprovado,
        t1.qt_votantes,
        t1.qt_votos_sim,
        t1.qt_votos_nao,
        t1.qt_obstrucao,
        t1.qt_partidos,
        t1.qt_votos_sim - t1.qt_votos_nao
            AS margem,
        ROUND(100.0 * t1.qt_votos_sim / NULLIF(t1.qt_votantes, 0), 2)
            AS perc_sim,
        t5.orientacao_voto
            AS orientacao_governo,
        (t1.qt_votos_sim = 0 OR t1.qt_votos_nao = 0)::BOOLEAN
            AS flag_unanimidade,
        (ROUND(100.0 * t1.qt_votos_sim / NULLIF(t1.qt_votantes, 0), 2) BETWEEN 45 AND 55)::BOOLEAN
            AS flag_votacao_apertada,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM placar AS t1
    INNER JOIN votacoes AS t2
        ON t1.sk_votacao = t2.sk_votacao
    LEFT JOIN legislaturas AS t3
        ON t2.data_votacao BETWEEN t3.inicio AND t3.fim
    LEFT JOIN presidente_da_data AS t4
        ON t1.sk_votacao = t4.sk_votacao
    LEFT JOIN orientacao_governo AS t5
        ON t1.sk_votacao = t5.sk_votacao
)

SELECT * FROM final
ORDER BY data_votacao DESC
