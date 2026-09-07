{{
  config(
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

{#-
  Metade de ESCRITA do loop de retroalimentação da planilha: publica a posição do
  mês corrente no mesmo layout da aba "classificacao", para ser colada de volta
  nela. A metade de leitura é stg_carteira_classificacao, que traz a camada
  preenchida à mão e entra no mart base `carteira`.

  Publica TUDO do mês atual, classificado ou não — é o retrato completo que
  substitui a aba. Quem quer só a pendência usa ativos_sem_classificacao, que
  responde a outra pergunta ("o que falta digitar?") e cabe numa mensagem.

  As colunas são exatamente as de stg_carteira_classificacao, na mesma ordem,
  incluindo codigo_ativo — que é o que identifica a posição no join de volta.
  Ficaram de fora indexador e tipo_ativo, que saíram do cadastro.
-#}

WITH
final AS (
    SELECT DISTINCT
        pessoa,
        instituicao,
        classe_ativo,
        codigo_ativo,
        ativo,
        data_vencimento,
        moeda_ativo,
        camada
    FROM {{ ref('carteira') }}
    WHERE fl_mes_atual IS TRUE
)

SELECT
    final.*,
    CURRENT_TIMESTAMP AS model_updated_at
FROM final
ORDER BY pessoa, camada, classe_ativo, instituicao, ativo
