{{
  config(
    tags = ['livros','intermediate'],
    )
}}

WITH
legado AS (
    SELECT * FROM {{ ref('stg_vide_all_books_legacy') }}
    WHERE book_name IS NOT NULL
),

home AS (
    SELECT * FROM {{ ref('stg_vide_home_featured') }}
    WHERE book_name IS NOT NULL
),

categorias AS (
    SELECT * FROM {{ ref('stg_vide_category_pages') }}
    WHERE book_name IS NOT NULL
),

unioned AS (
    SELECT
        book_id,
        book_name,
        book_category
    FROM legado
    UNION ALL
    SELECT
        book_id,
        book_name,
        NULL AS book_category
    FROM home
    UNION ALL
    SELECT
        book_id,
        book_name,
        book_category
    FROM categorias
),

unioned_dedup AS (
    SELECT
        book_id,
        MIN(book_name) AS book_name
    FROM unioned
    GROUP BY book_id
),

category_counts AS (
    SELECT
        book_id,
        book_category,
        COUNT(*) AS category_count
    FROM unioned
    WHERE book_category IS NOT NULL
    GROUP BY 1, 2
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY book_id
            ORDER BY
                category_count DESC,
                book_category ASC
        ) AS rn
    FROM category_counts
)

SELECT
    d.book_id,
    d.book_name,
    COALESCE(r.book_category,'desconhecido') AS book_category
FROM unioned_dedup AS d
LEFT JOIN ranked AS r
    ON d.book_id = r.book_id
    AND r.rn = 1
