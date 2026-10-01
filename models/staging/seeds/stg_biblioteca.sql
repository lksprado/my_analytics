{{
  config(
    tags = ['livros', 'staging'],
  )
}}


WITH
source AS (
    SELECT
        {{ clean_string("livros", 'lower') }} AS name,
        {{ clean_string("autor", 'lower') }}  AS author,
        {{ clean_string("tipo", 'lower') }}   AS type
    FROM {{ ref('seed_biblioteca') }}
)

SELECT * FROM source
