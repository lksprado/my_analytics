{{ config(
    tags=["politica"]
) }}

WITH
-- Só 24 votações do Senado têm orientação de GOVERNO que casa com dim_votacoes — o
-- codigovotacaosve do endpoint orientacaoBancada é outro espaço de chave. Deixar o Senado
-- entrar daria 1.658 linhas contra 1,4M da Câmara, que somem em qualquer agregação.
votacoes_orientadas_governo AS (
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
        data_proposicao,
        aprovado,
        orientacao_governo
    FROM {{ ref('votacoes_placar') }}
    WHERE casa = 'CAMARA'
        AND orientacao_governo IS NOT NULL
),

votos_parlamentares_joined AS (
    SELECT
        t2.casa,
        t1.sk_voto,
        t1.sk_parlamentar,
        t1.sk_votacao,
        t3.deputado_id_nk,
        t3.senador_id_nk,
        t2.votacao_id_nk,
        t3.nome,
        t3.uf,
        t1.partido,
        t1.partido_nome,
        t2.tipo_proposicao,
        t2.data_proposicao,
        t2.data_votacao,
        t2.ano,
        t2.trimestre,
        t2.legislatura,
        t2.presidente,
        t2.mandato,
        t2.aprovado,
        t1.voto,
        t2.orientacao_governo                                       AS voto_governo,
        CASE WHEN t1.voto = t2.orientacao_governo THEN 1 ELSE 0 END AS voto_alinhado
    FROM {{ ref('fct_votos') }} AS t1
    INNER JOIN votacoes_orientadas_governo AS t2
        ON t1.sk_votacao = t2.sk_votacao
    LEFT JOIN {{ ref('dim_parlamentares') }} AS t3
        ON t1.sk_parlamentar = t3.sk_parlamentar
    WHERE t1.sk_parlamentar <> '{{ var("null_key") }}'
),

final AS (
    SELECT
        sk_voto,
        sk_parlamentar,
        sk_votacao,

        votacao_id_nk,
        deputado_id_nk,
        senador_id_nk,

        casa,
        nome,
        uf,
        partido,
        partido_nome,
        tipo_proposicao,
        legislatura,
        presidente,
        mandato,
        aprovado,
        voto,
        voto_governo,
        voto_alinhado,

        data_proposicao,
        data_votacao,
        ano,
        trimestre,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM votos_parlamentares_joined
)

SELECT * FROM final
