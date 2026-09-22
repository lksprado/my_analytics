{{
  config(
    tags = ['financas', 'marts'],
  )
}}

WITH
carteira AS (
    SELECT
        mes_base,
        conglomerado_fgc,
        250000                  AS limite_fgc,
        SUM(vlr_atualizado_brl) AS total
    FROM {{ ref('carteira') }}
    WHERE
        1 = 1
        AND pessoa = 'lucas'
        AND fl_mes_atual IS TRUE
        AND conglomerado_fgc IS NOT NULL
        AND conglomerado_fgc <> 'NAO APLICAVEL'
    GROUP BY 1, 2, 3
),

calc AS (
    SELECT
        mes_base,
        conglomerado_fgc,
        limite_fgc - total AS vlr_liberado,
        CASE
            WHEN limite_fgc - total > 50000 THEN 'OK'
            ELSE 'PERIGO!'
        END                AS risco_fgc
    FROM carteira
)

SELECT
    calc.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM calc
