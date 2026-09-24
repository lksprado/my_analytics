{{ config(
    tags=["politica"]
) }}

WITH
votos AS (
    SELECT
        sk_voto,
        sk_votacao,
        sk_parlamentar,
        sk_partido,
        uf,
        partido,
        voto,
        orientacao_governo,
        orientacao_partido,
        fl_seguiu_governo,
        fl_seguiu_partido,
        fl_votou_com_resultado
    FROM {{ ref('fct_votos') }}
    WHERE
        voto IN ('SIM', 'NAO', 'OBSTRUCAO')
        AND sk_parlamentar <> '{{ var("null_key") }}'
),

final AS (
    SELECT
        t1.sk_voto,
        t1.sk_votacao,
        t1.sk_parlamentar,
        t1.sk_partido,
        t2.votacao_id_nk,
        t2.casa,
        t2.data_votacao,
        t2.ano,
        t2.trimestre,
        t2.legislatura,
        t2.presidente,
        t2.mandato,
        t2.tipo_orgao,
        t2.classe_votacao,
        t2.grupo_votacao,
        t2.tipo_proposicao,
        t2.identificacao_proposicao,
        t2.fl_aprovada,
        t3.nome,
        t3.sexo,
        t1.uf,
        t5.regiao,
        DATE_PART('year', AGE(t2.data_votacao, t3.data_nascimento))::INT
            AS idade,
        t1.partido,
        t4.rotulo
            AS partido_rotulo,
        t1.voto,
        t1.orientacao_governo,
        t1.orientacao_partido,
        t1.fl_seguiu_governo,
        t1.fl_seguiu_partido,
        t1.fl_votou_com_resultado,
        CASE
            WHEN t1.fl_seguiu_governo IS NULL OR t1.fl_seguiu_partido IS NULL THEN NULL
            WHEN t1.fl_seguiu_governo = 1 AND t1.fl_seguiu_partido = 1 THEN 'GOVERNO E PARTIDO'
            WHEN t1.fl_seguiu_governo = 1 THEN 'SO GOVERNO'
            WHEN t1.fl_seguiu_partido = 1 THEN 'SO PARTIDO'
            ELSE 'CONTRA AMBOS'
        END
            AS alinhamento,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM votos AS t1
    -- Contexto via votacoes: juntar as tabelas inteiras estoura a memória compartilhada do Postgres.
    INNER JOIN {{ ref('votacoes') }} AS t2
        ON t1.sk_votacao = t2.sk_votacao
    LEFT JOIN {{ ref('dim_parlamentares') }} AS t3
        ON t1.sk_parlamentar = t3.sk_parlamentar
    LEFT JOIN {{ ref('dim_partidos') }} AS t4
        ON t1.sk_partido = t4.sk_partido
    LEFT JOIN {{ ref('dim_uf') }} AS t5
        ON t1.uf = t5.uf
)

SELECT * FROM final
