{{
  config(
    tags = ['financas', 'marts'],
  )
}}

-- Janela até CURRENT ROW, não 1 PRECEDING: o *_acum de M já embute a taxa de M,
-- e com 1 PRECEDING a série inteira fica defasada em um mês.
-- Não é rentabilidade: a variação MoM inclui os aportes.

WITH casal_mom AS (
    SELECT
        mes_base,
        total_patrimonio_liquido,
        patrimonio_liquido_lucas,
        patrimonio_liquido_jessica
    FROM {{ ref('patrimonio_mom') }}
),

-- O LAG roda antes do recorte de 2023-11 para a primeira linha ter mês anterior.
deusa_mom AS (
    SELECT
        mes_base,
        (
            total_patrimonio_liquido::NUMERIC
            / NULLIF(LAG(total_patrimonio_liquido) OVER (ORDER BY mes_base), 0)
            - 1
        )::NUMERIC(18, 3) AS patrimonio_liquido_deusa
    FROM {{ ref('patrimonio_deusa') }}
),

-- LEFT JOIN: mês sem fechamento de Deusa não derruba a linha do casal; o índice
-- dela repete o anterior porque SUM de janela ignora NULL.
mom AS (
    SELECT
        t1.mes_base,
        t1.total_patrimonio_liquido,
        t1.patrimonio_liquido_lucas,
        t1.patrimonio_liquido_jessica,
        t2.patrimonio_liquido_deusa
    FROM casal_mom AS t1
    LEFT JOIN deusa_mom AS t2
        ON t1.mes_base = t2.mes_base
    WHERE t1.mes_base >= DATE '2023-11-01'
),

var_acum AS (
    SELECT
        mes_base,

        EXP(
            COALESCE(
                SUM(LN(1 + total_patrimonio_liquido)) OVER (
                    ORDER BY mes_base
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ),
                0
            )
        )::NUMERIC(18, 3) AS total_patrimonio_liquido_acum,

        EXP(
            COALESCE(
                SUM(LN(1 + patrimonio_liquido_lucas)) OVER (
                    ORDER BY mes_base
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ),
                0
            )
        )::NUMERIC(18, 3) AS patrimonio_liquido_lucas_acum,

        EXP(
            COALESCE(
                SUM(LN(1 + patrimonio_liquido_jessica)) OVER (
                    ORDER BY mes_base
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ),
                0
            )
        )::NUMERIC(18, 3) AS patrimonio_liquido_jessica_acum,

        EXP(
            COALESCE(
                SUM(LN(1 + patrimonio_liquido_deusa)) OVER (
                    ORDER BY mes_base
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ),
                0
            )
        )::NUMERIC(18, 3) AS patrimonio_liquido_deusa_acum

    FROM mom
),

indexadores AS (
    SELECT
        mes_base,
        minha_inflacao_acum,
        ipca_acum,
        igpm_acum,
        selic_acum,
        cdi_acum
    FROM {{ ref('int_indexadores') }}
),

final AS (
    SELECT
        t1.*,
        t2.minha_inflacao_acum,
        t2.ipca_acum,
        t2.igpm_acum,
        t2.selic_acum,
        t2.cdi_acum,
        CASE WHEN total_patrimonio_liquido_acum > minha_inflacao_acum THEN 'RICOS' ELSE 'POBRES' END AS comparativo_minha_inflacao_total_liquido,
        CASE WHEN patrimonio_liquido_lucas_acum > minha_inflacao_acum THEN 'RICO' ELSE 'POBRE' END   AS comparativo_minha_inflacao_lucas,
        CASE WHEN patrimonio_liquido_jessica_acum > minha_inflacao_acum THEN 'RICO' ELSE 'POBRE' END AS comparativo_minha_inflacao_jessica,
        CASE WHEN patrimonio_liquido_deusa_acum > minha_inflacao_acum THEN 'RICO' ELSE 'POBRE' END   AS comparativo_minha_inflacao_deusa,

        CASE WHEN total_patrimonio_liquido_acum > ipca_acum THEN 'RICOS' ELSE 'POBRES' END           AS comparativo_ipca_total_liquido,
        CASE WHEN patrimonio_liquido_lucas_acum > ipca_acum THEN 'RICO' ELSE 'POBRE' END             AS comparativo_ipca_lucas,
        CASE WHEN patrimonio_liquido_jessica_acum > ipca_acum THEN 'RICO' ELSE 'POBRE' END           AS comparativo_ipca_jessica,
        CASE WHEN patrimonio_liquido_deusa_acum > ipca_acum THEN 'RICO' ELSE 'POBRE' END             AS comparativo_ipca_deusa,

        CASE WHEN total_patrimonio_liquido_acum > igpm_acum THEN 'RICOS' ELSE 'POBRES' END           AS comparativo_igpm_total_liquido,
        CASE WHEN patrimonio_liquido_lucas_acum > igpm_acum THEN 'RICO' ELSE 'POBRE' END             AS comparativo_igpm_lucas,
        CASE WHEN patrimonio_liquido_jessica_acum > igpm_acum THEN 'RICO' ELSE 'POBRE' END           AS comparativo_igpm_jessica,
        CASE WHEN patrimonio_liquido_deusa_acum > igpm_acum THEN 'RICO' ELSE 'POBRE' END             AS comparativo_igpm_deusa,

        CASE WHEN total_patrimonio_liquido_acum > selic_acum THEN 'RICOS' ELSE 'POBRES' END          AS comparativo_selic_total_liquido,
        CASE WHEN patrimonio_liquido_lucas_acum > selic_acum THEN 'RICO' ELSE 'POBRE' END            AS comparativo_selic_lucas,
        CASE WHEN patrimonio_liquido_jessica_acum > selic_acum THEN 'RICO' ELSE 'POBRE' END          AS comparativo_selic_jessica,
        CASE WHEN patrimonio_liquido_deusa_acum > selic_acum THEN 'RICO' ELSE 'POBRE' END            AS comparativo_selic_deusa,

        CASE WHEN total_patrimonio_liquido_acum > cdi_acum THEN 'RICOS' ELSE 'POBRES' END            AS comparativo_cdi_total_liquido,
        CASE WHEN patrimonio_liquido_lucas_acum > cdi_acum THEN 'RICO' ELSE 'POBRE' END              AS comparativo_cdi_lucas,
        CASE WHEN patrimonio_liquido_jessica_acum > cdi_acum THEN 'RICO' ELSE 'POBRE' END            AS comparativo_cdi_jessica,
        CASE WHEN patrimonio_liquido_deusa_acum > cdi_acum THEN 'RICO' ELSE 'POBRE' END              AS comparativo_cdi_deusa
    FROM var_acum AS t1
    INNER JOIN indexadores AS t2
        ON t1.mes_base = t2.mes_base
)

SELECT
    final.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM final
ORDER BY final.mes_base
