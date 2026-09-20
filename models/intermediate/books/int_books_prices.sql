{{
  config(
    tags = ['livros','intermediate'],
    )
}}

WITH
legado AS (
    SELECT * FROM {{ ref('stg_vide_all_books_legacy') }}
),

home AS (
    SELECT * FROM {{ ref('stg_vide_home_featured') }}
),

categorias AS (
    SELECT * FROM {{ ref('stg_vide_category_pages') }}
),

unioned AS (
    SELECT
        created_date,
        name,
        author,
        price_old,
        price_new,
        discount
    FROM legado
    UNION ALL
    SELECT
        created_date,
        name,
        author,
        price_old,
        price_new,
        discount
    FROM home
    UNION ALL
    SELECT
        created_date,
        name,
        author,
        price_old,
        price_new,
        discount
    FROM categorias
),

-- As três fontes se sobrepõem; quando divergem no mesmo dia vale o menor preço.
diario AS (
    SELECT DISTINCT ON (name, author, created_date)
        created_date,
        name,
        author,
        price_old,
        price_new,
        discount
    FROM unioned
    WHERE price_new IS NOT NULL
    ORDER BY name ASC, author ASC, created_date ASC, price_new ASC
),

com_janelas AS (
    SELECT
        created_date,
        name,
        author,
        price_old,
        price_new,
        discount,

        ROW_NUMBER() OVER (
            PARTITION BY name, author
            ORDER BY created_date ASC
        ) AS observation_order,

        LAG(price_new) OVER (
            PARTITION BY name, author
            ORDER BY created_date ASC
        ) AS prev_price,

        LAG(created_date) OVER (
            PARTITION BY name, author
            ORDER BY created_date ASC
        ) AS prev_observed_at,

        MIN(price_new) OVER (
            PARTITION BY name, author
            ORDER BY created_date ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS min_price_before,

        -- A coleta alterna ~30 destaques diários com varreduras do catálogo inteiro:
        -- ancorar em max(created_date) global enxergaria menos de 1% dos livros.
        MAX(created_date) OVER (PARTITION BY name, author)                AS last_observed_at,
        MIN(created_date) OVER (PARTITION BY name, author)                AS first_observed_at,
        COUNT(*) OVER (PARTITION BY name, author)                         AS total_observations,
        MIN(price_new) OVER (PARTITION BY name, author)                   AS min_price_ever,
        MAX(price_new) OVER (PARTITION BY name, author)                   AS max_price_ever,
        AVG(price_new) OVER (PARTITION BY name, author)::NUMERIC(10, 2)   AS avg_price_ever,
        MAX(created_date) OVER ()                                         AS reference_date
    FROM diario
),

final AS (
    SELECT
        created_date,
        name,
        author,
        price_old,
        price_new,
        discount,
        observation_order,
        prev_price,
        prev_observed_at,
        min_price_before,
        first_observed_at,
        last_observed_at,
        reference_date,
        total_observations,
        min_price_ever,
        max_price_ever,
        avg_price_ever,

        (created_date - prev_observed_at)             AS days_since_prev_observation,
        (price_new - prev_price)                      AS price_change,
        (created_date = last_observed_at)             AS is_latest_observation,

        COALESCE(price_new < prev_price, FALSE)       AS is_price_drop,
        COALESCE(price_new > prev_price, FALSE)       AS is_price_increase,

        COALESCE(price_new < min_price_before, FALSE) AS is_record_low,

        (reference_date - last_observed_at)           AS days_since_last_observed,
        ((reference_date - last_observed_at) > 7)     AS is_stale_price,

        (price_new - min_price_ever)                  AS price_vs_min_ever,

        CASE
            WHEN min_price_ever > 0
                THEN ROUND(100.0 * (price_new - min_price_ever) / min_price_ever, 2)
        END                                           AS pct_above_min_ever,

        (price_new <= min_price_ever)                 AS is_at_record_low,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM com_janelas
)

SELECT * FROM final
