{{ config(
    materialized='ephemeral',
    tags=["politica"]
) }}


WITH source_paginas AS (
    SELECT
        dt_extracao,
        sigla,
        numero,
        ano,
        titulo ,
        tipo_proposicao,
        descritivo,
        votos_sim,
        votos_nao,
        link
    FROM {{ source('ecidadania','raw_ecidadania_paginas') }}
),
source_pagina_inicial AS (
    SELECT
        dt_extracao,
        sigla,
        numero,
        ano,
        titulo ,
        tipo_proposicao,
        descritivo,
        votos_sim,
        votos_nao,
        link
    FROM {{ source('ecidadania','raw_ecidadania_mais_votados') }}
),
unioned AS (
    SELECT * FROM source_paginas
    UNION ALL 
    SELECT * FROM source_pagina_inicial
)
SELECT * FROM unioned


