{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}


WITH
planilha AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        vlr_declarado_brl::BIGINT AS vlr_planilha_brl
    FROM {{ ref('int_planilha_investimentos_selecionados_alongados') }}
),

relatorio AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        SUM(vlr_atualizado_brl)::BIGINT AS vlr_relatorio_brl
    FROM {{ ref('int_relatorio_unificado') }}
    GROUP BY mes_base, pessoa, instituicao
),
max_mes AS (
    -- B3 é a extração que fecha o mês; sem ela, a planilha já fechada viraria um mês inteiro de resíduo.
    SELECT
        MAX(mes_base) AS max_mes_base
    FROM {{ ref('int_relatorio_unificado') }}
),

chaves AS (
    SELECT
        mes_base,
        pessoa,
        instituicao
    FROM planilha
    UNION
    SELECT
        mes_base,
        pessoa,
        instituicao
    FROM relatorio
),

valores AS (
    SELECT
        k.mes_base,
        k.pessoa,
        k.instituicao,
        p.vlr_planilha_brl,
        COALESCE(r.vlr_relatorio_brl, 0) AS vlr_relatorio_brl,
        p.vlr_planilha_brl
        - COALESCE(r.vlr_relatorio_brl, 0) AS vlr_faltante_brl
    FROM chaves AS k
    LEFT JOIN planilha AS p
        ON k.mes_base = p.mes_base
        AND k.pessoa = p.pessoa
        AND k.instituicao = p.instituicao
    LEFT JOIN relatorio AS r
        ON k.mes_base = r.mes_base
        AND k.pessoa = r.pessoa
        AND k.instituicao = r.instituicao
    INNER JOIN max_mes AS m
        ON k.mes_base = m.max_mes_base
)

SELECT
    *,
    CASE
        WHEN vlr_planilha_brl IS NULL
            THEN 'SEM DECLARACAO'        
        WHEN vlr_faltante_brl > 15
            THEN 'PREENCHER SEED'
        WHEN vlr_faltante_brl < -15 
            THEN 'LANÇAMENTO DUPLICADO'
        ELSE 'OK'
    END                                 AS status,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM valores
WHERE vlr_faltante_brl > 15 
ORDER BY mes_base, pessoa, instituicao
