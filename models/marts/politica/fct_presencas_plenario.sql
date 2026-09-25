{{ config(
    materialized='incremental',
    incremental_strategy='append',
    pre_hook="{{ apagar_periodo_vivo(\"TO_DATE(sk_data::TEXT, 'YYYYMMDD')\", 'legislatura') }}",
    post_hook="CREATE INDEX IF NOT EXISTS idx_fct_presencas_plenario_data ON {{ this }} (sk_data)",
    on_schema_change='append_new_columns',
    tags=["politica"]
) }}

-- depends_on: {{ ref('seed_legislaturas') }}

WITH
votacoes_plenario AS (
    SELECT
        v.sk_votacao,
        v.casa,
        v.sk_data,
        c.data,
        c.legislatura,
        v.modalidade_votacao,
        v.fl_governo_orientou
    FROM {{ ref('fct_votacoes') }} AS v
    INNER JOIN {{ ref('dim_orgaos') }} AS o
        ON v.sk_orgao = o.sk_orgao
    INNER JOIN {{ ref('dim_calendario_legislativo') }} AS c
        ON v.sk_data = c.data_sk
    WHERE
        o.tipo_orgao = 'PLENARIO'
        AND v.modalidade_votacao IN ('NOMINAL ABERTA', 'NOMINAL SECRETA')
        {% if is_incremental() -%}
            -- A janela de exercício da Câmara cresce com cada voto novo: a legislatura corrente é refeita inteira.
            AND c.data >= {{ inicio_periodo_vivo('legislatura') }}
        {%- endif %}
),

registros AS (
    SELECT
        f.sk_parlamentar,
        f.sk_votacao,
        f.casa,
        f.sk_tipo_voto,
        f.voto,
        f.sk_partido,
        f.uf,
        p.data,
        p.legislatura
    FROM {{ ref('fct_votos') }} AS f
    INNER JOIN votacoes_plenario AS p
        ON f.sk_votacao = p.sk_votacao
    WHERE f.sk_parlamentar <> '{{ var("null_key") }}'
),

-- A API da Câmara só lista quem votou: o deputado é tido em exercício entre o primeiro e o último voto na legislatura.
janelas_camara AS (
    SELECT
        sk_parlamentar,
        legislatura,
        MIN(data) AS inicio,
        MAX(data) AS fim
    FROM registros
    WHERE casa = 'CAMARA'
    GROUP BY sk_parlamentar, legislatura
),

cobertura AS (
    SELECT
        j.sk_parlamentar,
        p.sk_votacao
    FROM janelas_camara AS j
    INNER JOIN votacoes_plenario AS p
        ON p.casa = 'CAMARA'
        AND j.legislatura = p.legislatura
        AND p.data BETWEEN j.inicio AND j.fim
    UNION ALL
    -- O Senado lista todos os senadores em exercício, presentes ou não.
    SELECT
        sk_parlamentar,
        sk_votacao
    FROM registros
    WHERE casa = 'SENADO'
),

presencas AS (
    SELECT
        c.sk_parlamentar,
        c.sk_votacao,
        p.casa,
        p.sk_data,
        p.data,
        p.modalidade_votacao,
        p.fl_governo_orientou,
        r.sk_tipo_voto,
        r.voto,
        r.sk_partido,
        r.uf,
        (r.sk_votacao IS NULL)::INT AS fl_ausencia_inferida
    FROM cobertura AS c
    INNER JOIN votacoes_plenario AS p
        ON c.sk_votacao = p.sk_votacao
    LEFT JOIN registros AS r
        ON c.sk_parlamentar = r.sk_parlamentar AND c.sk_votacao = r.sk_votacao
),

-- A ausência inferida herda partido e UF do voto anterior: cada registro abre um grupo.
grupos AS (
    SELECT
        *,
        COUNT(sk_votacao) FILTER (WHERE fl_ausencia_inferida = 0) OVER (
            PARTITION BY sk_parlamentar
            ORDER BY data ASC, fl_ausencia_inferida ASC, sk_votacao ASC
            ROWS UNBOUNDED PRECEDING
        ) AS grupo
    FROM presencas
),

herdados AS (
    SELECT
        *,
        FIRST_VALUE(sk_partido) OVER (
            PARTITION BY sk_parlamentar, grupo
            ORDER BY data ASC, fl_ausencia_inferida ASC, sk_votacao ASC
        ) AS sk_partido_vigente,
        FIRST_VALUE(uf) OVER (
            PARTITION BY sk_parlamentar, grupo
            ORDER BY data ASC, fl_ausencia_inferida ASC, sk_votacao ASC
        ) AS uf_vigente
    FROM grupos
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['h.sk_parlamentar', 'h.sk_votacao']) }}       AS sk_presenca,
        h.sk_parlamentar,
        h.sk_votacao,
        h.sk_data,
        COALESCE(h.sk_tipo_voto, '{{ var("null_key") }}')                                  AS sk_tipo_voto,
        COALESCE(h.sk_partido_vigente, '{{ var("null_key") }}')                            AS sk_partido,
        h.casa,
        h.modalidade_votacao,
        COALESCE(h.uf_vigente, '{{ var("null_string") }}')                                 AS uf,
        CASE WHEN h.fl_ausencia_inferida = 1 THEN 'AUSENCIA INFERIDA' ELSE t.categoria END AS categoria_presenca,
        CASE WHEN h.fl_ausencia_inferida = 1 THEN 0 ELSE t.fl_presente END                 AS fl_presente,
        h.fl_ausencia_inferida,
        COALESCE((h.voto IN ('SIM', 'NAO', 'OBSTRUCAO'))::INT, 0)                          AS fl_votou_com_posicao,
        h.fl_governo_orientou,
        '{{ run_started_at }}'::TIMESTAMPTZ                                                AS model_run_at
    FROM herdados AS h
    LEFT JOIN {{ ref('dim_tipo_voto') }} AS t
        ON h.sk_tipo_voto = t.sk_tipo_voto
)

SELECT * FROM final
