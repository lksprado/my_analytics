{{ config(
    tags=["politica"]
) }}

WITH
votos AS (
    SELECT * FROM {{ ref('fct_votos') }}
    WHERE
        fl_seguiu_governo IS NOT NULL
        AND sk_parlamentar <> '{{ var("null_key") }}'
),

final AS (
    SELECT
        t1.sk_voto,
        t1.sk_parlamentar,
        t1.sk_votacao,

        t1.votacao_id_nk,
        t2.deputado_id_nk,
        t2.senador_id_nk,

        t1.casa,
        t2.nome,
        t2.uf,
        t1.partido,
        t1.partido_nome,
        t3.tipo_proposicao,
        t3.legislatura,
        t3.presidente,
        t3.mandato,
        t3.aprovado,
        t1.voto,
        t1.orientacao_governo               AS voto_governo,
        t1.fl_seguiu_governo                AS voto_alinhado,

        t3.data_proposicao,
        t3.data_votacao,
        t3.ano,
        t3.trimestre,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM votos AS t1
    LEFT JOIN {{ ref('dim_parlamentares') }} AS t2
        ON t1.sk_parlamentar = t2.sk_parlamentar
    -- O recorte temporal e institucional vem pronto de votacoes_placar, que só tem as votações
    -- nominais: juntar fct_votacoes, calendário e proposições inteiros estoura a memória
    -- compartilhada do Postgres quando vários modelos rodam em paralelo.
    LEFT JOIN {{ ref('votacoes_placar') }} AS t3
        ON t1.sk_votacao = t3.sk_votacao
)

SELECT * FROM final
