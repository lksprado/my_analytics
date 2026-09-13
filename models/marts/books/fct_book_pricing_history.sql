{{
  config(
    tags = ['livros','marts'],
    )
}}

WITH
prices AS (
    SELECT * FROM {{ ref('int_books_price_history') }}
),

books AS (
    SELECT * FROM {{ ref('dim_book') }}
),

final AS (
    SELECT
        t2.book_sk,
        t1.created_date,
        t1.is_latest_observation,
        t1.price_old,
        t1.price_new,
        t1.discount,
        t1.observation_order,
        t1.prev_price,
        t1.prev_observed_at,
        t1.days_since_prev_observation,
        t1.price_change,
        t1.min_price_before,
        t1.is_price_drop,
        t1.is_price_increase,
        t1.is_record_low
    FROM prices AS t1
    LEFT JOIN books AS t2
        ON t1.name = t2.name
        AND t1.author = t2.author

)

SELECT * FROM final
ORDER BY created_date DESC
