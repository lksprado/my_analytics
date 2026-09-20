{{
  config(
    tags = ['livros', 'staging'],
  )
}}

WITH
source AS (
    SELECT * FROM {{ source('vide_editora', 'vide_raw_all_books_legacy') }}
),

renamed AS (
    SELECT
        NULLIF({{ clean_string('book_name', 'lower') }}, '')                                           AS name,
        NULLIF({{ clean_string('book_author','lower') }}, '')                                          AS author,
        TRIM(REPLACE(REPLACE(REPLACE(book_price_old, 'R$ ', ''), '.', ''), ',', '.'))::NUMERIC(10, 2) AS price_old,
        TRIM(REPLACE(REPLACE(REPLACE(book_price_new, 'R$ ', ''), '.', ''), ',', '.'))::NUMERIC(10, 2) AS price_new,
        TO_DATE(time, 'YYYY-MM-DD HH24:MI:SS')                                                        AS created_date,
        CASE
            WHEN
                LOWER(book_category) LIKE '%filósofo%'
                OR LOWER(book_category) LIKE '%filosofia%'
                OR LOWER(book_category) LIKE '%filosófico%' THEN 'filosofia'
            WHEN LOWER(book_category) = 'lógica e dialética' THEN 'filosofia'
            WHEN LOWER(book_category) = 'oratória e retórica' THEN 'filosofia'
            WHEN LOWER(book_category) = 'metafísica' THEN 'filosofia'

            WHEN LOWER(book_category) = 'história do Brasil' THEN 'historia'
            WHEN LOWER(book_category) = 'história' THEN 'historia'
            WHEN LOWER(book_category) = 'história da américa latina' THEN 'historia'

            WHEN LOWER(book_category) = 'ciências sociais' THEN 'ciencias sociais'
            WHEN LOWER(book_category) = 'antropologia' THEN 'ciencias sociais'
            WHEN LOWER(book_category) = 'sociologia' THEN 'ciencias sociais'

            WHEN LOWER(book_category) = 'autoconhecimento' THEN 'autoconhecimento'
            WHEN LOWER(book_category) = 'auto-ajuda' THEN 'autoconhecimento'

            WHEN LOWER(book_category) LIKE '%literatura%' THEN 'literatura'
            WHEN LOWER(book_category) LIKE '%teatro%' THEN 'literatura'

            WHEN LOWER(book_category) = 'biografias' THEN 'biografias'
            WHEN LOWER(book_category) = 'ensino e estudo de línguas' THEN 'linguas'
            WHEN LOWER(book_category) = 'políticos' THEN 'ciencia politica '

        END                                                                                           AS category
    FROM source
    WHERE book_category IN (
        'Filósofos Brasileiros',
        'Literatura Estrangeira',
        'História do Brasil',
        'Filósofos',
        'Filosofia da História',
        'Filosofia Política',
        'Ciências Sociais',
        'Filosofia',
        'Filosofia Moderna e Contemporânea',
        'Literatura Brasileira',
        'Lógica e Dialética',
        'Ensaios e Estudos Filosóficos',
        'Oratória e Retórica',
        'Ética e Filosofia Moral',
        'Literatura',
        'Metafísica',
        'Biografias',
        'História da Filosofia',
        'Auto-Ajuda',
        'Introdução à Filosofia',
        'Literatura Portuguesa',
        'Linguística',
        'Autoconhecimento',
        'Antropologia',
        'Filosofia Antiga',
        'História',
        'História da América Latina',
        'Sociologia',
        'Políticos',
        'Teatro Grego',
        'Teatro'
    )
),

final AS (
    SELECT
        name,
        category,
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
