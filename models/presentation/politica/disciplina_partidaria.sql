{{ config(
    tags=["camara", "parlamentar", "votacoes"]
) }}

WITH
-- A junção não infla: dim_orientacao_votacoes tem 96.455 linhas para 96.455 pares distintos
-- de (sk_votacao, sigla_partido_bloco).
orientacao_por_partido AS (
    SELECT
        sk_votacao,
        sigla_partido_bloco,
        orientacao_voto
    FROM {{ ref('dim_orientacao_votacoes') }}
    WHERE sk_votacao <> '{{ var("null_key") }}'
),

-- Mesmo motivo de governismo: no Senado só 1.674 dos 27.400 votos têm orientação do próprio
-- partido, contra 1.118.127 na Câmara. Não sustenta métrica.
votacoes AS (
    SELECT
        sk_votacao,
        votacao_id_nk,
        casa,
        data_votacao,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato,
        tipo_proposicao,
        aprovado
    FROM {{ ref('votacoes_placar') }}
    WHERE casa = 'CAMARA'
),

final AS (
    SELECT
        t1.sk_voto,
        t1.sk_parlamentar,
        t1.sk_votacao,
        t2.votacao_id_nk,
        t2.casa,
        t4.nome,
        t4.uf,
        t1.partido,
        t1.partido_nome,
        t2.tipo_proposicao,
        t2.legislatura,
        t2.presidente,
        t2.mandato,
        t2.aprovado,
        t1.voto,
        t3.orientacao_voto                                       AS orientacao_partido,
        CASE WHEN t1.voto = t3.orientacao_voto THEN 1 ELSE 0 END AS voto_segue_partido,
        t2.data_votacao,
        t2.ano,
        t2.trimestre,
        '{{ run_started_at }}'::TIMESTAMPTZ                      AS model_run_at
    FROM {{ ref('fct_votos') }} AS t1
    INNER JOIN votacoes AS t2
        ON t1.sk_votacao = t2.sk_votacao
    INNER JOIN orientacao_por_partido AS t3
        ON t1.sk_votacao = t3.sk_votacao AND t1.partido = t3.sigla_partido_bloco
    LEFT JOIN {{ ref('dim_parlamentares') }} AS t4
        ON t1.sk_parlamentar = t4.sk_parlamentar
    WHERE t1.sk_parlamentar <> '{{ var("null_key") }}'
)

SELECT * FROM final
