{{
  config(
    tags = ['livros','presentation'],
    )
}}

WITH
obt AS (
    SELECT * FROM {{ ref('livros_precos_obt') }}
),

atual AS (
    SELECT *
    FROM obt
    WHERE fl_ultima_observacao
        AND NOT fl_preco_desatualizado
),

-- Compara só com observações anteriores: incluir a atual faria todo preço empatar consigo mesmo.
historico AS (
    SELECT
        t1.book_sk,
        COUNT(*)                                                             AS qtd_observacoes_anteriores,
        MAX(t2.preco)                                                        AS preco_maximo_anterior,
        (PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY t2.preco))::NUMERIC(10, 2) AS preco_mediano_anterior,
        MAX(t2.desconto_pct)                                                 AS desconto_maximo_anterior_pct,
        MAX(t2.data_observacao) FILTER (WHERE t2.preco <= t1.preco)          AS ultima_vez_tao_barato,
        ROUND(100.0 * AVG((t2.preco > t1.preco)::INT), 1)                    AS pct_observacoes_mais_caras
    FROM atual AS t1
    INNER JOIN obt AS t2
        ON t1.book_sk = t2.book_sk
        AND t2.data_observacao < t1.data_observacao
    GROUP BY t1.book_sk
),

classificado AS (
    SELECT
        t1.*,
        t2.qtd_observacoes_anteriores,
        t2.preco_maximo_anterior,
        t2.preco_mediano_anterior,
        t2.desconto_maximo_anterior_pct,
        t2.ultima_vez_tao_barato,
        t2.pct_observacoes_mais_caras,
        CASE
            WHEN t1.preco < t1.preco_minimo_ate_entao THEN 1
            WHEN t1.preco = t1.preco_minimo_ate_entao THEN 2
            WHEN t1.desconto_pct > t2.desconto_maximo_anterior_pct THEN 3
            WHEN t1.preco <= t1.preco_minimo_ate_entao * 1.05 THEN 4
        END AS ordem_faixa
    FROM atual AS t1
    INNER JOIN historico AS t2
        ON t1.book_sk = t2.book_sk
    -- Perto do mínimo não basta: um livro que passa a maior parte do tempo nesse preço não está em oportunidade.
    WHERE t2.qtd_observacoes_anteriores >= 3
        AND t1.preco < t2.preco_mediano_anterior
),

-- Coautores geram uma linha por autor com números idênticos; colapsa numa linha por livro.
por_livro AS (
    SELECT
        ordem_faixa,
        nome_livro,
        STRING_AGG(autor, ', ' ORDER BY autor) AS autores,
        categoria,
        data_observacao,
        tipo_coleta,
        preco_lista,
        preco,
        desconto_pct,
        preco_anterior,
        preco_minimo_ate_entao,
        preco_mediano_anterior,
        preco_maximo_anterior,
        desconto_maximo_anterior_pct,
        ultima_vez_tao_barato,
        pct_observacoes_mais_caras,
        desconto_mediano_catalogo_pct,
        percentil_desconto_catalogo,
        desconto_extra_vs_catalogo_pp,
        qtd_observacoes_anteriores,
        primeira_observacao
    FROM classificado
    WHERE ordem_faixa IS NOT NULL
    GROUP BY
        ordem_faixa,
        nome_livro,
        categoria,
        data_observacao,
        tipo_coleta,
        preco_lista,
        preco,
        desconto_pct,
        preco_anterior,
        preco_minimo_ate_entao,
        preco_mediano_anterior,
        preco_maximo_anterior,
        desconto_maximo_anterior_pct,
        ultima_vez_tao_barato,
        pct_observacoes_mais_caras,
        desconto_mediano_catalogo_pct,
        percentil_desconto_catalogo,
        desconto_extra_vs_catalogo_pp,
        qtd_observacoes_anteriores,
        primeira_observacao
),

final AS (
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY
                ordem_faixa,
                (1 - preco / preco_mediano_anterior) DESC,
                nome_livro
        )                                                            AS ranking,
        CASE ordem_faixa
            WHEN 1 THEN 'novo minimo'
            WHEN 2 THEN 'empata com o minimo'
            WHEN 3 THEN 'desconto recorde'
            WHEN 4 THEN 'ate 5% acima do minimo'
        END                                                          AS faixa_oportunidade,
        nome_livro,
        autores,
        categoria,
        data_observacao,
        tipo_coleta,

        preco_lista,
        preco,
        desconto_pct,
        preco_anterior,
        preco_minimo_ate_entao                                       AS preco_minimo_anterior,
        preco_mediano_anterior,
        preco_maximo_anterior,
        preco_mediano_anterior - preco                               AS economia_vs_mediana,
        ROUND(100 * (1 - preco / preco_mediano_anterior), 1)         AS economia_vs_mediana_pct,
        ROUND(100 * (preco / preco_minimo_ate_entao - 1), 1)         AS pct_acima_minimo_anterior,
        desconto_maximo_anterior_pct,
        ultima_vez_tao_barato,
        pct_observacoes_mais_caras,

        desconto_mediano_catalogo_pct,
        percentil_desconto_catalogo,
        desconto_extra_vs_catalogo_pp,

        qtd_observacoes_anteriores,
        primeira_observacao
    FROM por_livro
)

SELECT * FROM final
