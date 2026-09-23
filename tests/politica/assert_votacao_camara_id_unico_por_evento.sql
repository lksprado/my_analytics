{{ config(tags=["politica"]) }}

-- Um id natural não pode nomear votações distintas da Câmara (data, órgão ou descrição diferentes).
SELECT votacao_id_nk
FROM {{ ref('stg_camara_votacoes') }}
GROUP BY votacao_id_nk
HAVING COUNT(DISTINCT ROW(data_votacao, sigla_orgao, descricao)) > 1
