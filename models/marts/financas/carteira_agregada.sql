{{
  config(
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

{#-
  Carteira agregada por mês x pessoa, com uma coluna por instituição. Substitui
  o antigo int_carteira_agregada, que lia dois modelos intermediários hoje
  extintos; agora a fonte é uma só, o mart base `carteira`.

  `pessoa` fica no GROUP BY (linha), não no pivot: dbt_utils.pivot gira UMA
  coluna só, e cruzar pessoa x instituição em colunas exigiria uma expressão
  concatenada — daria ~30 colunas, a maioria zerada, e o conjunto mudaria a cada
  conta aberta ou fechada. Mantendo pessoa como grão da linha, este modelo
  serve os três carteira_<pessoa>_agregada, que viram um filtro sobre ele.

  TOTAIS: o corte é por `classe_ativo`, não pelo modelo de origem. O antigo
  int_carteira_agregada separava investido de disponibilidade pela tabela de
  onde a linha vinha, porque int_carteira trazia algumas contas correntes
  misturadas (o CASH da Avenue entrava por int_renda_variavel). O refactor do
  intermediate mudou isso: o CASH da Avenue foi para
  int_disponibilidades_isoladas e classe_ativo passou a ser fiel. Consequência
  desejada — some a divergência de R$ 259 que existia entre
  carteira_deusa_agregada.total_disponibilidades e a fronteira
  disponível/investido usada no relatório de meio de mês. Agora há uma definição
  só. As colunas por instituição somam TODAS as posições, então vale
  `soma das colunas = total_geral = total_investido + total_disponibilidades`.

  `vlr_liquido_usd` (saldo Avenue em moeda original, que a conversão para BRL
  apaga) reproduz o antigo int_carteira_usd a partir de staging, e é juntado
  DEPOIS da agregação, de propósito: já está no grão mês x pessoa, então o join
  é 1:1 com o resultado e não com as posições. Dentro do GROUP BY o valor era
  replicado em cada linha e somado N vezes — saía inflado pela contagem de
  posições da pessoa no mês.

  A lista de instituições é lida em tempo de compilação; o `default` cobre a
  build do zero, quando a tabela ainda não existe e a consulta voltaria vazia. O
  guard em `execute` é necessário porque get_column_values devolve Undefined — e
  não o default — na fase de parse (dbt_utils 1.4.1 + Jinja 3.1), o que
  estouraria no `| unique` abaixo; o ref() fica fora do guard para o DAG
  continuar enxergando a dependência.
-#}
{%- set rel_carteira = ref('carteira') -%}
{%- set default_instituicoes = [
    'AUTOCUSTODIA', 'AVENUE', 'BANCO DO BRASIL', 'BRADESCO', 'DAYCOVAL',
    'DESCONHECIDO', 'ITAU', 'NUBANK', 'SOFISA', 'WISE'
] -%}

{%- if execute -%}
    {%- set inst = dbt_utils.get_column_values(rel_carteira, 'instituicao', default = default_instituicoes) -%}
{%- else -%}
    {%- set inst = default_instituicoes -%}
{%- endif -%}

{%- set instituicoes = inst | reject('none') | unique | sort -%}

WITH
posicoes AS (
    SELECT
        mes_base,
        mes_final,
        pessoa,
        instituicao,
        classe_ativo,
        vlr_atualizado_brl
    FROM {{ rel_carteira }}
),

{#- Saldo Avenue na moeda original. Reproduz int_carteira_usd: posições e
    proventos somados no grão período x pessoa. -#}
usd AS (
    SELECT
        period_start,
        pessoa,
        SUM(vlr_liquido_usd) AS vlr_liquido_usd
    FROM (
        SELECT
            period_start,
            pessoa,
            SUM(market_value)::INT AS vlr_liquido_usd
        FROM {{ ref('stg_assets') }}
        GROUP BY period_start, pessoa

        UNION ALL

        SELECT
            period_start,
            pessoa,
            SUM(vlr_liquido_usd)::INT AS vlr_liquido_usd
        FROM {{ ref('stg_dividends_interest') }}
        GROUP BY period_start, pessoa
    ) AS t
    GROUP BY period_start, pessoa
),

agregado AS (
    SELECT
        p.mes_base,
        p.mes_final,
        p.pessoa,
        SUM(p.vlr_atualizado_brl)                                                                 AS total_geral,
        COALESCE(SUM(p.vlr_atualizado_brl) FILTER (WHERE p.classe_ativo = 'DISPONIBILIDADE'), 0)  AS total_disponibilidades,
        COALESCE(SUM(p.vlr_atualizado_brl) FILTER (WHERE p.classe_ativo <> 'DISPONIBILIDADE'), 0) AS total_investido,
        {{ dbt_utils.pivot(
            'instituicao',
            instituicoes,
            agg = 'sum',
            then_value = 'vlr_atualizado_brl',
            quote_identifiers = False
        ) }}
    FROM posicoes AS p
    GROUP BY p.mes_base, p.mes_final, p.pessoa
)

SELECT
    a.*,
    COALESCE(u.vlr_liquido_usd, 0) AS vlr_liquido_usd,
    CURRENT_TIMESTAMP              AS model_updated_at
FROM agregado AS a
LEFT JOIN usd AS u
    ON u.period_start = a.mes_base
    AND u.pessoa = a.pessoa
ORDER BY a.mes_final, a.pessoa
