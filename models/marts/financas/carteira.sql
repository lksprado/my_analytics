{{
  config(
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

{#-
  Base da camada de carteira: toda posição de todo titular, mês a mês, com o
  enriquecimento que o intermediate deliberadamente não faz.

  int_ativos_consolidados já une renda fixa, renda variável e disponibilidades
  no mesmo grão — é a "visão única de ativos" crua. O que se acrescenta aqui:

    mes_final / trimestre / ano   join com dim_datas
    camada                        classificação manual lida da planilha
    fl_mes_atual                  a posição pertence ao mês mais recente?

  fonte_dado NÃO nasce aqui: é atribuído lá atrás, no CTE-folha de cada ramo do
  intermediate (B3, AVENUE, PLANILHA GOOGLE ou SEED), porque depois do UNION ALL
  a origem já não é recuperável. Aqui ele só é carregado adiante. Serve para
  separar o que uma extração traz do que é digitado à mão, e para distinguir
  "a extração não rodou" de "a posição sumiu".

  Feito uma vez só. Os três carteira_<pessoa>, os três risco_fgc_<pessoa>,
  carteira_agregada, carteira_classificacao e ativos_sem_classificacao são todos
  recortes deste modelo — antes o mesmo LATERAL de camada estava copiado em dois
  modelos intermediários e as cópias divergiram, que é a mesma história da macro
  normaliza_instituicao.

  CAMADA NÃO É MAIS SCD2. A aba "classificacao" da planilha perdeu a coluna
  mes_base e virou um cadastro de estado atual, então não há vigência a resolver:
  o join é direto e um mês passado carrega a classificação de hoje. Enquanto
  havia mes_base, isto era um LEFT JOIN LATERAL pegando a última linha com
  mes_base <= a do mês da posição.

  A chave é pessoa + codigo_ativo + instituicao. Sem instituicao há fan-out:
  BRSTNCLTN806 da Deusa está cadastrado no Banco do Brasil e no Nubank, e o join
  por pessoa + codigo_ativo devolvia 85 linhas para 83 posições.
-#}

WITH
datas AS (
    SELECT DISTINCT
        month_start_date,
        month_end_date,
        quarter_of_year,
        year_number
    FROM {{ ref('dim_datas') }}
),

posicoes AS (
    SELECT * FROM {{ ref('int_ativos_consolidados') }}
),

classificacao AS (
    SELECT
        pessoa,
        codigo_ativo,
        instituicao,
        camada
    FROM {{ ref('stg_carteira_classificacao') }}
),

final AS (
    SELECT
        t1.mes_base,
        t2.month_end_date  AS mes_final,
        t2.quarter_of_year AS trimestre,
        t2.year_number     AS ano,
        t1.pessoa,
        t1.instituicao,
        t1.emissor,
        t1.conglomerado_fgc,
        t1.classe_ativo,
        t1.tipo_ativo,
        t1.codigo_ativo,
        COALESCE(t3.camada, 'NAO CLASSIFICADO') AS camada,
        t1.ativo,
        t1.indexador,
        t1.data_vencimento,
        t1.vencimento_em_dias,
        t1.fl_vencido,
        t1.vlr_atualizado_brl,
        t1.moeda_ativo,
        t1.fonte_dado,
        t1.mes_base = MAX(t1.mes_base) OVER () AS fl_mes_atual
    FROM posicoes AS t1
    INNER JOIN datas AS t2
        ON t1.mes_base = t2.month_start_date
    LEFT JOIN classificacao AS t3
        ON t1.pessoa = t3.pessoa
        AND t1.codigo_ativo = t3.codigo_ativo
        AND t1.instituicao = t3.instituicao
)

SELECT
    final.*,
    CURRENT_TIMESTAMP AS model_updated_at
FROM final
ORDER BY mes_base, pessoa, instituicao, classe_ativo, tipo_ativo, ativo
