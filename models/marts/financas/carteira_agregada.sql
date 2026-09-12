{{
  config(
    materialized = 'table',
    tags = ['financas', 'marts'],
  )
}}

{#- pessoa fica no GROUP BY e não no pivot: dbt_utils.pivot gira uma coluna só,
    e pessoa x instituição daria ~30 colunas quase todas zeradas.

    Os totais cortam por classe_ativo; as colunas por instituição somam todas as
    posições, então soma das colunas = total_geral = total_investido +
    total_disponibilidades.

    vlr_liquido_usd é juntado depois da agregação: dentro do GROUP BY o valor
    era somado uma vez por posição.

    get_column_values devolve Undefined, e não o default, na fase de parse; daí
    o guard em execute. O ref() fica fora do guard para o DAG ver a dependência. -#}
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
