{{
  config(
    tags = ['livros','presentation'],
    )
}}

WITH
precos AS (
    SELECT * FROM {{ ref('fct_book_pricing') }}
),

books AS (
    SELECT * FROM {{ ref('dim_book') }}
),

datas AS (
    SELECT * FROM {{ ref('dim_datas') }}
),

campanhas AS (
    SELECT * FROM {{ ref('livros_campanhas') }}
),

enriquecido AS (
    SELECT
        t1.book_sk,
        t1.created_date,
        t2.name,
        t2.author,
        t2.category,
        t1.price_old,
        t1.price_new,
        t1.observation_order,
        t1.prev_price,
        t1.prev_observed_at,
        t1.days_since_prev_observation,
        t1.price_change,
        t1.min_price_before,
        t1.is_price_drop,
        t1.is_price_increase,
        t1.is_record_low,
        t1.is_latest_observation,
        t1.is_stale_price,
        t1.first_observed_at,
        t1.last_observed_at,
        t1.total_observations,
        t1.min_price_ever,
        t1.max_price_ever,
        t1.avg_price_ever,
        ROUND(100 * (1 - t1.price_new / NULLIF(t1.price_old, 0)), 1)       AS desconto_pct,
        t1.price_old <> LAG(t1.price_old) OVER (
            PARTITION BY t1.book_sk
            ORDER BY t1.created_date
        )                                                                  AS fl_mudanca_preco_lista,
        COUNT(*) OVER (
            PARTITION BY t2.name, t1.created_date, t1.price_old, t1.price_new
        )                                                                  AS qtd_autores_livro,
        ROW_NUMBER() OVER (
            PARTITION BY t2.name, t1.created_date, t1.price_old, t1.price_new
            ORDER BY t2.author
        ) = 1                                                              AS fl_linha_principal
    FROM precos AS t1
    INNER JOIN books AS t2
        ON t1.book_sk = t2.book_sk
),

final AS (
    SELECT
        t1.book_sk,
        t3.data_sk,
        t1.created_date                                          AS data_observacao,
        t3.year_number                                           AS ano,
        t3.month_of_year                                         AS mes,
        t3.mes_sk,
        LOWER(t3.month_name)                                     AS nome_mes,
        t3.iso_week_of_year                                      AS semana_iso,
        LOWER(t3.day_of_week_name)                               AS nome_dia_semana,
        t3.fl_dia_util,

        t1.name                                                  AS nome_livro,
        t1.author                                                AS autor,
        t1.category                                              AS categoria,
        t1.qtd_autores_livro,
        t1.fl_linha_principal,

        CASE
            WHEN t4.data_varredura = t1.created_date THEN 'varredura completa'
            ELSE 'destaques'
        END                                                      AS tipo_coleta,
        t4.data_varredura                                        AS data_varredura_referencia,
        t4.desconto_mediano_pct                                  AS desconto_mediano_catalogo_pct,
        t4.percentil_desconto                                    AS percentil_desconto_catalogo,
        t1.desconto_pct - t4.desconto_mediano_pct                AS desconto_extra_vs_catalogo_pp,

        t1.price_old                                             AS preco_lista,
        t1.price_new                                             AS preco,
        t1.desconto_pct,
        t1.fl_mudanca_preco_lista,
        t1.observation_order                                     AS ordem_observacao,
        t1.prev_price                                            AS preco_anterior,
        t1.prev_observed_at                                      AS data_observacao_anterior,
        t1.days_since_prev_observation                           AS dias_desde_observacao_anterior,
        t1.price_change                                          AS variacao_preco,
        ROUND(100 * t1.price_change / NULLIF(t1.prev_price, 0), 1) AS variacao_preco_pct,
        t1.min_price_before                                      AS preco_minimo_ate_entao,
        t1.is_price_drop                                         AS fl_queda,
        t1.is_price_increase                                     AS fl_alta,
        t1.is_record_low                                         AS fl_novo_minimo,

        t1.is_latest_observation                                 AS fl_ultima_observacao,
        t1.is_stale_price                                        AS fl_preco_desatualizado,
        t1.first_observed_at                                     AS primeira_observacao,
        t1.last_observed_at                                      AS ultima_observacao,
        t1.total_observations                                    AS qtd_observacoes,
        t1.min_price_ever                                        AS preco_minimo_historico,
        t1.max_price_ever                                        AS preco_maximo_historico,
        t1.avg_price_ever                                        AS preco_medio_historico
    FROM enriquecido AS t1
    INNER JOIN datas AS t3
        ON t1.created_date = t3.date_day
    -- Dias de destaques herdam a campanha da varredura mais recente até a data.
    LEFT JOIN LATERAL (
        SELECT
            c.data_varredura,
            c.desconto_mediano_pct,
            c.percentil_desconto
        FROM campanhas AS c
        WHERE c.data_varredura <= t1.created_date
        ORDER BY c.data_varredura DESC
        LIMIT 1
    ) AS t4 ON TRUE
)

SELECT * FROM final
