{{
  config(
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

-- Crescimento acumulado do patrimônio contra os indexadores, por mês.
--
-- Alinhamento temporal: o índice da linha do mês M tem que refletir o nível de
-- patrimônio DE M, porque é contra o `*_acum` de M que ele é comparado, e o
-- índice dos indexadores já embute a taxa do próprio mês
-- (cdi_acum(M) = cdi_acum(M-1) * (1 + cdi(M))). Por isso a janela vai até
-- CURRENT ROW. Ela já foi `1 PRECEDING`, o que zerava a primeira linha em
-- 1,000 exatos mas defasava a série inteira em um mês: o gráfico comparava o
-- patrimônio de maio com o CDI de junho.
--
-- NÃO É RENTABILIDADE: a variação MoM inclui os aportes do período. Ver a
-- descrição do modelo em _schema.yml.

WITH casal_mom AS (
    SELECT
        mes_base,
        total_patrimonio_liquido,
        patrimonio_liquido_lucas,
        patrimonio_liquido_jessica
    FROM {{ ref('patrimonio_mom') }}
),

-- Deusa vem de outra planilha e de outro modelo: `patrimonio_deusa`
-- traz só o total líquido, sem abertura por titular, então não há um
-- `patrimonio_mom` dela para reaproveitar e a variação MoM é calculada aqui.
-- O LAG roda sobre a série inteira, antes do recorte de 2023-11, para que a
-- primeira linha da janela tenha mês anterior com que se comparar.
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

-- LEFT JOIN e não INNER: um mês sem fechamento da planilha de Deusa não pode
-- derrubar a linha do casal. Onde ela falta, o índice dela repete o anterior
-- (SUM de janela ignora NULL) e a coluna segue legível.
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
    CURRENT_TIMESTAMP AS model_updated_at
FROM final
ORDER BY final.mes_base
