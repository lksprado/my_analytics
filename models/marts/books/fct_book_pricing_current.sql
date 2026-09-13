{{
  config(
    tags = ['livros','marts'],
    )
}}

WITH

atual AS (
    SELECT * FROM {{ ref('int_books_price_current') }}
),

books AS (
    SELECT * FROM {{ ref('dim_book') }}
),

final AS (
    SELECT
        t2.book_sk,
        t1.last_observed_at,
        t1.reference_date,
        t1.days_since_last_observed,
        t1.is_stale_price,
        t1.price_old,
        t1.current_price,
        t1.current_discount,
        t1.prev_price,
        t1.price_change,
        t1.is_price_drop,
        t1.min_price_ever,
        t1.max_price_ever,
        t1.avg_price_ever,
        t1.price_vs_min_ever,
        t1.pct_above_min_ever,
        t1.is_at_record_low,
        t1.is_new_record_low,
        t1.first_observed_at,
        t1.total_observations
    FROM atual AS t1
    LEFT JOIN books AS t2
        ON t1.name = t2.name
        AND t1.author = t2.author
)

SELECT * FROM final
ORDER BY pct_above_min_ever ASC, current_price ASC
