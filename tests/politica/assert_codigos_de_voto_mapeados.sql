{{ config(tags=["politica"]) }}

-- Todo código de voto da origem precisa estar em seed_tipos_voto.
WITH codigos AS (
    SELECT DISTINCT
        'CAMARA'                        AS casa,
        COALESCE(voto, 'NAO INFORMADO') AS codigo_origem
    FROM {{ ref('stg_camara_votos_deputados') }}
    UNION
    SELECT DISTINCT
        'SENADO',
        COALESCE(sigla_voto, 'NAO INFORMADO')
    FROM {{ ref('stg_senado_votos_senadores') }}
)

SELECT c.*
FROM codigos AS c
LEFT JOIN {{ ref('seed_tipos_voto') }} AS s
    ON c.casa = s.casa AND c.codigo_origem = s.codigo_origem
WHERE s.codigo_origem IS NULL
