{{ config(tags=["politica"]) }}

-- Nenhum fato do domínio traz data posterior à execução.
SELECT
    'votacoes'        AS tabela,
    MAX(data_votacao) AS data_maxima
FROM {{ ref('votacoes') }}
HAVING MAX(data_votacao) > '{{ run_started_at }}'::DATE
UNION ALL
SELECT
    'fct_consultas_publicas' AS tabela,
    MAX(data_extracao)       AS data_maxima
FROM {{ ref('fct_consultas_publicas') }}
HAVING MAX(data_extracao) > '{{ run_started_at }}'::DATE
UNION ALL
SELECT
    'fct_indicadores_externos' AS tabela,
    MAX(data_coleta)           AS data_maxima
FROM {{ ref('fct_indicadores_externos') }}
HAVING MAX(data_coleta) > '{{ run_started_at }}'::DATE
