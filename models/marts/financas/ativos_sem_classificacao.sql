{{
  config(
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

{#-
  A pendência do loop da planilha: posições do mês corrente que ainda não têm
  linha na aba "classificacao" e por isso caem no default 'NAO CLASSIFICADO'
  dentro do mart base `carteira`.

  Complemento de carteira_classificacao, que publica o retrato inteiro do mês —
  aqui sai só o que falta digitar.

  O anti-join é NOT EXISTS: PostgreSQL não tem LEFT ANTI JOIN. A chave é
  pessoa + codigo_ativo + instituicao, a mesma do join de camada; instituicao
  entra porque um mesmo codigo_ativo pode estar cadastrado em dois bancos.

  O recorte é fl_mes_atual, não uma data fixa: meses antigos sempre terão
  pendência, porque a planilha só cadastra o que se tem hoje.
-#}

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
    CURRENT_TIMESTAMP AS model_updated_at
FROM faltam_classificar
ORDER BY pessoa, vlr_atualizado_brl DESC
