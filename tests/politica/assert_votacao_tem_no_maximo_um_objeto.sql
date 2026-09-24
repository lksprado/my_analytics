{{ config(tags=["politica"]) }}

-- Uma votação tem no máximo uma proposição objeto; as demais relações têm outro tipo.
SELECT
    sk_votacao,
    COUNT(*) AS qt_objetos
FROM {{ ref('bridge_votacoes_proposicoes') }}
WHERE tipo_relacao = 'OBJETO'
GROUP BY sk_votacao
HAVING COUNT(*) > 1
