{{ config(
    materialized='incremental',
    incremental_strategy='append',
    pre_hook="{{ apagar_periodo_vivo(\"TO_DATE(sk_data::TEXT, 'YYYYMMDD')\", 'legislatura') }}",
    post_hook="CREATE INDEX IF NOT EXISTS idx_fct_votacoes_data ON {{ this }} (sk_data)",
    on_schema_change='append_new_columns',
    tags=["politica"]
) }}

-- depends_on: {{ ref('seed_legislaturas') }}

WITH
votacoes AS (
    SELECT * FROM {{ ref('int_votacoes_unificadas') }}
    {% if is_incremental() -%}
        -- Votos e orientações da votação chegam depois dela: a legislatura corrente é refeita inteira.
        WHERE data_votacao >= {{ inicio_periodo_vivo('legislatura') }}
    {%- endif %}
),

placar AS (
    SELECT
        casa,
        votacao_id_nk,
        COUNT(*) FILTER (WHERE voto = 'SIM')                                                      AS qt_votos_sim,
        COUNT(*) FILTER (WHERE voto = 'NAO')                                                      AS qt_votos_nao,
        COUNT(*) FILTER (WHERE voto = 'OBSTRUCAO')                                                AS qt_obstrucao,
        COUNT(*) FILTER (WHERE voto = 'ABSTENCAO')                                                AS qt_abstencao,
        COUNT(*) FILTER (WHERE voto IN ('SIM', 'NAO', 'OBSTRUCAO'))                               AS qt_votantes,
        COUNT(*) FILTER (WHERE categoria = 'PRESENTE SEM VOTO')                                   AS qt_presentes_sem_voto,
        COUNT(*) FILTER (WHERE categoria IN ('AUSENCIA JUSTIFICADA', 'AUSENCIA NAO JUSTIFICADA')) AS qt_ausentes,
        COUNT(DISTINCT partido) FILTER (WHERE voto IN ('SIM', 'NAO', 'OBSTRUCAO'))                AS qt_partidos
    FROM {{ ref('int_votos_unificados') }}
    {% if is_incremental() -%}
        WHERE
            (casa, votacao_id_nk) IN (
                SELECT
                    casa,
                    votacao_id_nk
                FROM votacoes
            )
    {%- endif %}
    GROUP BY casa, votacao_id_nk
),

orientacao_governo AS (
    SELECT
        casa,
        votacao_id_nk,
        orientacao_voto
    FROM {{ ref('int_orientacoes_unificadas') }}
    WHERE sigla_lideranca = 'GOVERNO'
),

proposicoes AS (
    SELECT
        sk_proposicao,
        casa,
        proposicao_id_nk
    FROM {{ ref('dim_proposicoes') }}
),

medidas AS (
    SELECT
        v.casa,
        v.votacao_id_nk,
        v.sessao_id,
        v.data_votacao,
        v.sigla_orgao,
        v.classe_votacao,
        v.descricao,
        p.sk_proposicao,
        g.orientacao_voto                                                              AS orientacao_governo,
        v.aprovado                                                                     AS fl_aprovada,
        CAST(COALESCE(pl.qt_votantes, 0) > 0 AS INTEGER)                               AS fl_nominal,
        v.fl_secreta,
        CASE
            WHEN v.fl_secreta = 1 THEN 'NOMINAL SECRETA'
            WHEN COALESCE(pl.qt_votantes, 0) > 0 THEN 'NOMINAL ABERTA'
            ELSE 'SEM REGISTRO NOMINAL'
        END                                                                            AS modalidade_votacao,
        COALESCE(CAST(g.orientacao_voto IN ('SIM', 'NAO', 'OBSTRUCAO') AS INTEGER), 0) AS fl_governo_orientou,
        -- Obstrução busca derrubar a matéria: conta como NÃO.
        CASE
            WHEN g.orientacao_voto = 'SIM' THEN v.aprovado
            WHEN g.orientacao_voto IN ('NAO', 'OBSTRUCAO') THEN 1 - v.aprovado
        END                                                                            AS fl_resultado_alinhado_governo,
        CASE
            WHEN g.orientacao_voto IS NULL THEN 'SEM ORIENTACAO'
            WHEN g.orientacao_voto = 'LIBERADO' THEN 'LIBERADO'
            WHEN g.orientacao_voto NOT IN ('SIM', 'NAO', 'OBSTRUCAO') THEN 'ORIENTACAO ' || g.orientacao_voto
            WHEN v.aprovado IS NULL THEN 'RESULTADO NAO BINARIO'
        END                                                                            AS motivo_resultado_nao_classificado,
        -- Na votação secreta o voto individual é só VOTOU: o placar vem do total oficial.
        COALESCE(v.qt_votos_sim_secreta, pl.qt_votos_sim, 0)                           AS qt_votos_sim,
        COALESCE(v.qt_votos_nao_secreta, pl.qt_votos_nao, 0)                           AS qt_votos_nao,
        COALESCE(pl.qt_obstrucao, 0)                                                   AS qt_obstrucao,
        COALESCE(v.qt_abstencao_secreta, pl.qt_abstencao, 0)                           AS qt_abstencao,
        COALESCE(v.qt_votos_sim_secreta + v.qt_votos_nao_secreta, pl.qt_votantes, 0)   AS qt_votantes,
        COALESCE(pl.qt_presentes_sem_voto, 0)                                          AS qt_presentes_sem_voto,
        COALESCE(pl.qt_ausentes, 0)                                                    AS qt_ausentes,
        COALESCE(pl.qt_partidos, 0)                                                    AS qt_partidos
    FROM votacoes AS v
    LEFT JOIN placar AS pl
        ON v.casa = pl.casa AND v.votacao_id_nk = pl.votacao_id_nk
    LEFT JOIN orientacao_governo AS g
        ON v.casa = g.casa AND v.votacao_id_nk = g.votacao_id_nk
    LEFT JOIN proposicoes AS p
        ON v.casa = p.casa AND v.proposicao_id_nk = p.proposicao_id_nk
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['m.casa', 'm.votacao_id_nk']) }} AS sk_votacao,
        m.votacao_id_nk,
        m.casa,
        m.sessao_id,
        CAST(TO_CHAR(m.data_votacao, 'YYYYMMDD') AS INTEGER)                  AS sk_data,
        COALESCE(m.sk_proposicao, '{{ var("null_key") }}')                    AS sk_proposicao,
        COALESCE(o.sk_orgao, '{{ var("null_key") }}')                         AS sk_orgao,
        COALESCE(t.sk_tipo_votacao, '{{ var("null_key") }}')                  AS sk_tipo_votacao,
        m.descricao,
        m.modalidade_votacao,
        m.orientacao_governo,
        m.fl_aprovada,
        m.fl_nominal,
        m.fl_secreta,
        m.fl_governo_orientou,
        m.fl_resultado_alinhado_governo,
        m.motivo_resultado_nao_classificado,
        m.qt_votos_sim,
        m.qt_votos_nao,
        m.qt_obstrucao,
        m.qt_abstencao,
        m.qt_votantes,
        m.qt_presentes_sem_voto,
        m.qt_ausentes,
        m.qt_partidos,
        '{{ run_started_at }}'::TIMESTAMPTZ                                   AS model_run_at
    FROM medidas AS m
    LEFT JOIN {{ ref('dim_orgaos') }} AS o
        ON m.casa = o.casa AND m.sigla_orgao = o.sigla_orgao
    LEFT JOIN {{ ref('dim_tipo_votacao') }} AS t
        ON m.classe_votacao = t.classe_votacao
        AND m.fl_nominal = t.fl_nominal
        AND m.fl_secreta = t.fl_secreta
)

SELECT * FROM final
