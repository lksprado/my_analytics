{{
  config(
    tags = ['livros', 'staging'],
  )
}}


WITH
source AS (
    SELECT
        id                                         AS google_book_id,
        {{ clean_string("titulo", 'lower') }}      AS name,
        {{ clean_string("subtitle", 'lower') }}    AS subtitle,
        {{ clean_string("author", 'lower') }}      AS author,
        {{ clean_string("publisher", 'lower') }}   AS publisher,
        TO_DATE(published_date, 'YYYY-MM-DD')      AS published_date,
        page_count::INT                            AS page_count,
        {{ clean_string("categories", 'lower') }}  AS category,
        {{ clean_string("language", 'lower') }}    AS language,
        isbn_10,
        isbn_13,
        {{ clean_string("description", 'lower') }} AS description
    FROM {{ source('google_books', 'livros') }}
)

SELECT * FROM source
