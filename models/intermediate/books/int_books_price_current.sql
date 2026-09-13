{{
  config(
    tags = ['livros','intermediate'],
    )
}}

-- A coleta alterna ~30 destaques diários com varreduras do catálogo inteiro:
-- ancorar em max(created_date) global enxergaria menos de 1% dos livros.

WITH
historico AS (
    SELECT * FROM {{ ref('int_books_price_history') }}
),

ultima_observacao AS (
    SELECT *
    FROM historico
    WHERE is_latest_observation
),

agregados AS (
    SELECT
        name,
        author,
        AVG(price_new)::NUMERIC(10, 2) AS avg_price_ever,
        MIN(price_new)                 AS min_price_ever,
        MAX(price_new)                 AS max_price_ever,
        MIN(created_date)              AS first_observed_at,
        COUNT(*)                       AS total_observations
    FROM historico
    GROUP BY name, author
),

referencia AS (
    SELECT MAX(created_date) AS reference_date
    FROM historico
),

final AS (
    SELECT
        t1.name,
        t1.author,
        t1.created_date                             AS last_observed_at,
        t3.reference_date,
        t1.price_old,

        t1.price_new                                AS current_price,
        t1.discount                                 AS current_discount,
        t1.prev_price,
        t1.price_change,
        t1.is_price_drop,
        t2.min_price_ever,

        t2.max_price_ever,
        t2.avg_price_ever,
        t2.first_observed_at,
        t2.total_observations,
        t1.is_record_low                            AS is_new_record_low,

        (t3.reference_date - t1.created_date)       AS days_since_last_observed,
        (t1.price_new - t2.min_price_ever)          AS price_vs_min_ever,

        CASE
            WHEN t2.min_price_ever > 0
                THEN ROUND(100.0 * (t1.price_new - t2.min_price_ever) / t2.min_price_ever, 2)
        END                                         AS pct_above_min_ever,

        t1.price_new <= t2.min_price_ever           AS is_at_record_low,

        ((t3.reference_date - t1.created_date) > 7) AS is_stale_price
    FROM ultima_observacao AS t1
    INNER JOIN agregados AS t2
        ON t1.name = t2.name
        AND t1.author = t2.author
    CROSS JOIN referencia AS t3
)

SELECT * FROM final
