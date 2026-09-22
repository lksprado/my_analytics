{{
  config(
    tags = ['financas', 'marts'],
  )
}}

{#- fl_mes_atual e não uma data fixa: meses antigos sempre têm pendência, porque
    a planilha só cadastra o que se tem hoje. -#}

WITH
faltam_classificar AS (
    SELECT DISTINCT
        c.pessoa,
        c.instituicao,
        c.classe_ativo,
        c.tipo_ativo,
        c.codigo_ativo,
        c.ativo,
        c.data_vencimento,
        c.moeda_ativo,
        c.vlr_atualizado_brl
    FROM {{ ref('carteira') }} AS c
    WHERE
        c.fl_mes_atual IS TRUE
        AND NOT EXISTS (
            SELECT 1
            FROM {{ ref('stg_carteira_classificacao') }} AS k
            WHERE
                k.pessoa = c.pessoa
                AND k.codigo_ativo = c.codigo_ativo
                AND k.instituicao = c.instituicao
        )
)

SELECT
    faltam_classificar.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM faltam_classificar
ORDER BY pessoa, vlr_atualizado_brl DESC
