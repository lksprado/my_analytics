{{ config(
    tags=["politica"]
) }}

WITH
votos AS (
    SELECT * FROM {{ ref('int_votos_unificados') }}
),

-- O voto herda do cabeçalho as chaves dimensionais e a orientação do governo.
votacoes AS (
    SELECT
        sk_votacao,
        casa,
        votacao_id_nk,
        sk_data,
        sk_proposicao,
        orientacao_governo,
        fl_aprovada,
        fl_governo_orientou
    FROM {{ ref('fct_votacoes') }}
),

orientacoes_partido AS (
    SELECT
        casa,
        votacao_id_nk,
        sigla_lideranca,
        orientacao_voto
    FROM {{ ref('int_orientacoes_unificadas') }}
),

parlamentares AS (
    SELECT
        sk_parlamentar,
        deputado_id_nk,
        senador_id_nk
    FROM {{ ref('dim_parlamentares') }}
),

tipos_voto AS (
    SELECT
        sk_tipo_voto,
        casa,
        codigo_origem
    FROM {{ ref('dim_tipo_voto') }}
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['v.casa', 'v.parlamentar_id_nk', 'v.votacao_id_nk']) }} AS sk_voto,
        COALESCE(vt.sk_votacao, '{{ var("null_key") }}')                                             AS sk_votacao,
        COALESCE(pd.sk_parlamentar, ps.sk_parlamentar, '{{ var("null_key") }}')                      AS sk_parlamentar,
        vt.sk_data,
        COALESCE(vt.sk_proposicao, '{{ var("null_key") }}')                                          AS sk_proposicao,
        COALESCE(tv.sk_tipo_voto, '{{ var("null_key") }}')                                           AS sk_tipo_voto,
        v.casa,
        v.votacao_id_nk,
        v.partido,
        v.partido_nome,
        v.voto,
        vt.orientacao_governo,
        o.orientacao_voto                                                                            AS orientacao_partido,
        COALESCE(vt.fl_governo_orientou, 0)                                                          AS fl_governo_orientou,
        CASE
            WHEN vt.fl_governo_orientou = 1 AND v.voto IN ('SIM', 'NAO', 'OBSTRUCAO')
                THEN (v.voto = vt.orientacao_governo)::INT
        END                                                                                          AS fl_seguiu_governo,
        COALESCE((o.orientacao_voto IN ('SIM', 'NAO', 'OBSTRUCAO'))::INT, 0)                         AS fl_partido_orientou,
        CASE
            WHEN o.orientacao_voto IN ('SIM', 'NAO', 'OBSTRUCAO') AND v.voto IN ('SIM', 'NAO', 'OBSTRUCAO')
                THEN (v.voto = o.orientacao_voto)::INT
        END                                                                                          AS fl_seguiu_partido,
        CASE v.voto
            WHEN 'SIM' THEN vt.fl_aprovada
            WHEN 'NAO' THEN 1 - vt.fl_aprovada
        END                                                                                          AS fl_votou_com_resultado,
        '{{ run_started_at }}'::TIMESTAMPTZ                                                          AS model_run_at
    FROM votos AS v
    LEFT JOIN votacoes AS vt
        ON v.casa = vt.casa AND v.votacao_id_nk = vt.votacao_id_nk
    LEFT JOIN orientacoes_partido AS o
        ON v.casa = o.casa AND v.votacao_id_nk = o.votacao_id_nk AND v.partido = o.sigla_lideranca
    -- Um lookup por casa, cada um por uma coluna só: juntar por (casa, COALESCE(ids)) faz o
    -- planner casar só pela casa e comparar cada voto com todos os parlamentares dela.
    LEFT JOIN parlamentares AS pd
        ON v.casa = 'CAMARA' AND v.parlamentar_id_nk = pd.deputado_id_nk
    LEFT JOIN parlamentares AS ps
        ON v.casa = 'SENADO' AND v.parlamentar_id_nk = ps.senador_id_nk
    LEFT JOIN tipos_voto AS tv
        ON v.casa = tv.casa AND v.codigo_voto = tv.codigo_origem
)

SELECT * FROM final
