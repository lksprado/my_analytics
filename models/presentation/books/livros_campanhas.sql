{{
  config(
    tags = ['livros','presentation'],
    )
}}

WITH
precos AS (
    SELECT * FROM {{ ref('fct_book_pricing') }}
),

books AS (
    SELECT * FROM {{ ref('dim_book') }}
),

-- Coautores repetem o livro uma vez por autor; a mesma combinação de nome e preços no dia é um livro só.
livros_dia AS (
    SELECT DISTINCT
        t1.created_date,
        t2.name,
        t1.price_old,
        t1.price_new,
        t1.min_price_before
    FROM precos AS t1
    INNER JOIN books AS t2
        ON t1.book_sk = t2.book_sk
),

por_dia AS (
    SELECT
        created_date,
        COUNT(*) AS qtd_livros
    FROM livros_dia
    GROUP BY created_date
),

-- A coleta diária de destaques traz ~30 livros; a varredura do catálogo, milhares.
varreduras AS (
    SELECT created_date
    FROM por_dia
    WHERE qtd_livros >= 0.5 * (SELECT MAX(qtd_livros) FROM por_dia)
),

agregado AS (
    SELECT
        t1.created_date                                                                  AS data_varredura,
        COUNT(*)                                                                         AS qtd_livros,
        ROUND(AVG(t1.price_new), 2)                                                      AS preco_medio,
        ROUND(
            (PERCENTILE_CONT(0.5) WITHIN GROUP (
                ORDER BY 100 * (1 - t1.price_new / NULLIF(t1.price_old, 0))
            ))::NUMERIC, 1
        )                                                                                AS desconto_mediano_pct,
        ROUND(AVG(100 * (1 - t1.price_new / NULLIF(t1.price_old, 0))), 1)                AS desconto_medio_pct,
        COUNT(*) FILTER (WHERE t1.price_new < t1.min_price_before)                       AS qtd_livros_novo_minimo
    FROM livros_dia AS t1
    INNER JOIN varreduras AS t2
        ON t1.created_date = t2.created_date
    GROUP BY t1.created_date
),

final AS (
    SELECT
        data_varredura,
        qtd_livros,
        preco_medio,
        desconto_mediano_pct,
        desconto_medio_pct,
        desconto_mediano_pct - LAG(desconto_mediano_pct) OVER (ORDER BY data_varredura) AS variacao_desconto_pp,
        ROUND(PERCENT_RANK() OVER (ORDER BY desconto_mediano_pct)::NUMERIC, 2)           AS percentil_desconto,
        qtd_livros_novo_minimo,
        ROUND(100.0 * qtd_livros_novo_minimo / qtd_livros, 1)                            AS pct_livros_novo_minimo,
        data_varredura = MAX(data_varredura) OVER ()                                     AS fl_ultima_varredura,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM agregado
)

SELECT * FROM final
