{{
  config(
    tags = ['livros','marts'],
    )
}}

WITH unioned AS (

    SELECT
        name,
        author,
        category
    FROM {{ ref('stg_vide_all_books_legacy') }}

    UNION ALL

    SELECT
        name,
        author,
        category
    FROM {{ ref('stg_vide_category_pages') }}

),

category_counts AS (

    SELECT
        name,
        author,
        category,
        COUNT(*) AS category_count
    FROM unioned
    WHERE category IS NOT NULL
    GROUP BY 1, 2, 3

),

ranked AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY name, author
            ORDER BY
                category_count DESC,
                category ASC
        ) AS rn
    FROM category_counts

),

filtered AS (

    SELECT
        name,
        author,
        category
    FROM ranked
    WHERE rn = 1

),

books AS (

    SELECT
        name,
        author
    FROM {{ ref('stg_vide_all_books_legacy') }}

    UNION

    SELECT
        name,
        author
    FROM {{ ref('stg_vide_category_pages') }}

    UNION

    SELECT
        name,
        author
    FROM {{ ref('stg_vide_home_featured') }}

),

final AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key(['books.name', 'books.author']) }} AS book_sk,

        books.name,

        COALESCE(
            books.author,
            'desconhecido'
        )                                                                      AS author,

        COALESCE(
            filtered.category,
            'desconhecido'
        )                                                                      AS category,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at

    FROM books

    LEFT JOIN filtered
        ON books.name = filtered.name
        AND books.author = filtered.author

)

SELECT *
FROM final
