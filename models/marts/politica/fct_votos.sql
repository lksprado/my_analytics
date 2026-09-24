{{ config(
    tags=["politica"]
) }}

WITH
votos AS (
    SELECT * FROM {{ ref('int_votos_unificados') }}
),

votacoes AS (
    SELECT
        sk_votacao,
        casa,
        votacao_id_nk,
        sk_data,
        sk_proposicao,
        sk_orgao,
        sk_tipo_votacao,
        orientacao_governo,
        fl_aprovada,
        fl_governo_orientou
    FROM {{ ref('fct_votacoes') }}
),

-- Casa pela entidade partidária, não pela sigla (PR orienta o PL).
orientacoes_partido AS (
    SELECT
        casa,
        votacao_id_nk,
        partido_id_senado,
        orientacao_voto
    FROM {{ ref('int_orientacoes_unificadas') }}
    WHERE partido_id_senado IS NOT NULL
),

partidos AS (
    SELECT
        sk_partido,
        partido_id_nk
    FROM {{ ref('dim_partidos') }}
),

parlamentares AS (
    SELECT
        sk_parlamentar,
        deputado_id_nk,
        senador_id_nk
    FROM {{ ref('dim_parlamentares') }}
),

bancadas AS (
    SELECT
        sk_bancada,
        sk_partido,
        casa,
        sigla_bancada,
        tipo_bancada,
        inicio,
        COALESCE(fim, DATE '9999-12-31') AS fim
    FROM {{ ref('bridge_bancadas_partidos') }}
),

-- A federação vale antes do bloco: é o agrupamento mais específico do partido.
bancada_na_votacao AS (
    SELECT DISTINCT ON (v.casa, v.votacao_id_nk, b.sk_partido)
        v.casa,
        v.votacao_id_nk,
        b.sk_partido,
        b.sk_bancada,
        b.sigla_bancada
    FROM votacoes AS v
    INNER JOIN bancadas AS b
        ON v.casa = b.casa
        AND TO_DATE(v.sk_data::TEXT, 'YYYYMMDD') BETWEEN b.inicio AND b.fim
    ORDER BY v.casa ASC, v.votacao_id_nk ASC, b.sk_partido ASC, (b.tipo_bancada = 'FEDERACAO') DESC, b.sigla_bancada ASC
),

orientacoes_bancada AS (
    SELECT
        casa,
        votacao_id_nk,
        sigla_lideranca,
        orientacao_voto
    FROM {{ ref('int_orientacoes_unificadas') }}
    WHERE partido_id_senado IS NULL
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
        COALESCE(pt.sk_partido, '{{ var("null_key") }}')                                             AS sk_partido,
        COALESCE(bv.sk_bancada, '{{ var("null_key") }}')                                             AS sk_bancada,
        vt.sk_data,
        COALESCE(vt.sk_proposicao, '{{ var("null_key") }}')                                          AS sk_proposicao,
        COALESCE(vt.sk_orgao, '{{ var("null_key") }}')                                               AS sk_orgao,
        COALESCE(vt.sk_tipo_votacao, '{{ var("null_key") }}')                                        AS sk_tipo_votacao,
        COALESCE(tv.sk_tipo_voto, '{{ var("null_key") }}')                                           AS sk_tipo_voto,
        v.casa,
        COALESCE(v.uf, '{{ var("null_string") }}')                                                   AS uf,
        v.votacao_id_nk,
        v.partido,
        v.partido_nome,
        v.voto,
        vt.orientacao_governo,
        o.orientacao_voto                                                                            AS orientacao_partido,
        ob.orientacao_voto                                                                           AS orientacao_bancada,
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
        CASE
            WHEN ob.orientacao_voto IN ('SIM', 'NAO', 'OBSTRUCAO') AND v.voto IN ('SIM', 'NAO', 'OBSTRUCAO')
                THEN (v.voto = ob.orientacao_voto)::INT
        END                                                                                          AS fl_seguiu_bancada,
        CASE v.voto
            WHEN 'SIM' THEN vt.fl_aprovada
            WHEN 'NAO' THEN 1 - vt.fl_aprovada
        END                                                                                          AS fl_votou_com_resultado,
        '{{ run_started_at }}'::TIMESTAMPTZ                                                          AS model_run_at
    FROM votos AS v
    LEFT JOIN votacoes AS vt
        ON v.casa = vt.casa AND v.votacao_id_nk = vt.votacao_id_nk
    LEFT JOIN orientacoes_partido AS o
        ON v.casa = o.casa AND v.votacao_id_nk = o.votacao_id_nk AND v.partido_id_senado = o.partido_id_senado
    -- Join por coluna única: com (casa, COALESCE(ids)) o planner compara cada voto com a casa inteira.
    LEFT JOIN parlamentares AS pd
        ON v.casa = 'CAMARA' AND v.parlamentar_id_nk = pd.deputado_id_nk
    LEFT JOIN parlamentares AS ps
        ON v.casa = 'SENADO' AND v.parlamentar_id_nk = ps.senador_id_nk
    LEFT JOIN tipos_voto AS tv
        ON v.casa = tv.casa AND v.codigo_voto = tv.codigo_origem
    LEFT JOIN partidos AS pt
        ON v.partido_id_senado = pt.partido_id_nk
    LEFT JOIN bancada_na_votacao AS bv
        ON v.casa = bv.casa AND v.votacao_id_nk = bv.votacao_id_nk AND pt.sk_partido = bv.sk_partido
    LEFT JOIN orientacoes_bancada AS ob
        ON bv.casa = ob.casa AND bv.votacao_id_nk = ob.votacao_id_nk AND bv.sigla_bancada = ob.sigla_lideranca
)

SELECT * FROM final
