{{
  config(
    tags = ['financas', 'marts'],
  )
}}

-- LEFT JOIN, ao contrário de `riqueza`: mês com indexador ainda não preenchido
-- aparece com NULL em vez de sumir. É esse NULL que o portão pronto_indicadores lê.

WITH indexadores AS (
    SELECT * FROM {{ ref('int_indexadores') }}
),

datas AS (
    SELECT
        date_day           AS mes_base,
        quarter_of_year    AS trimestre,
        year_number        AS ano
    FROM {{ ref('dim_datas') }}
),

final AS (
    SELECT
        t1.mes_base,
        t2.trimestre,
        t2.ano,

        -- Fração decimal (0,0042 = 0,42%), já dividida por 100 no staging.
        t1.minha_inflacao,
        t1.ipca,
        t1.igpm,
        t1.selic,
        t1.cdi,

        t1.minha_inflacao_acum,
        t1.ipca_acum,
        t1.igpm_acum,
        t1.selic_acum,
        t1.cdi_acum
    FROM indexadores AS t1
    LEFT JOIN datas AS t2
        ON t1.mes_base = t2.mes_base
)

SELECT
    final.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM final
ORDER BY final.mes_base
