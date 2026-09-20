{{
  config(
    tags = ['livros', 'staging'],
  )
}}

WITH
source AS (
    SELECT * FROM {{ source('vide_editora', 'vide_raw_home_featured') }}
),

renamed AS (
    SELECT
        NULLIF({{ clean_string('name', 'lower') }}, '')                                           AS name,
        NULLIF({{ clean_string('author_name','lower') }}, '')                                     AS author,
        TRIM(REPLACE(REPLACE(REPLACE(price_old, 'R$ ', ''), '.', ''), ',', '.'))::NUMERIC(10, 2) AS price_old,
        TRIM(REPLACE(REPLACE(REPLACE(price_new, 'R$ ', ''), '.', ''), ',', '.'))::NUMERIC(10, 2) AS price_new,
        created_at::DATE                                                                         AS created_date
    FROM source
),

final AS (
    SELECT
        name,
        price_old,
        price_new,
        ((price_new - price_old) / price_old)::NUMERIC(6, 2) AS discount,
        created_date,
        TRIM(a.author)                                       AS author,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM renamed
    CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(renamed.author, ',')) AS a (author)
)

SELECT * FROM final
