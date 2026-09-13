{{
  config(
    materialized = 'table',
    tags = ['livros', 'staging'],
  )
}}

WITH
source AS (
    SELECT * FROM {{ source('vide_editora', 'vide_raw_home_featured') }}
),

renamed AS (
    SELECT
        NULLIF({{ clean_string('name', 'lower') }},'')                                           AS name,
        NULLIF({{ clean_string('author_name','lower') }},'')                                     AS author,
        TRIM(REPLACE(REPLACE(REPLACE(price_old, 'R$ ', ''), '.', ''), ',', '.'))::NUMERIC(10, 2) AS price_old,
        TRIM(REPLACE(REPLACE(REPLACE(price_new, 'R$ ', ''), '.', ''), ',', '.'))::NUMERIC(10, 2) AS price_new,
        created_at::DATE                                                                         AS created_date
    FROM source
),

final AS (
    SELECT
        name,
        TRIM(a.author) as author,
        price_old,
        price_new,
        ((price_new - price_old) / price_old)::NUMERIC(6, 2) AS discount,
        created_date
    FROM renamed
    CROSS JOIN LATERAL unnest(string_to_array(renamed.author, ',')) a(author)
)

SELECT * FROM final
