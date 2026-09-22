{{ config(
    tags=["ecidadania", "participacao"]
) }}


WITH
proposicoes AS (
    SELECT * FROM {{ ref('stg_ecidadania_paginas') }}
),

mais_votados AS (
    SELECT * FROM {{ ref('stg_ecidadania_mais_votados') }}
)

-- Identificador do grão da e-Cidadania, NÃO uma FK de dim_proposicoes: aqui a proposição
-- é o rótulo textual ('MPV 1327/2025') e lá é o id numérico da casa. Das 28 proposições
-- desta fonte, só 1 casa com a identificacao de stg_senado_processo, então não há de-para.
SELECT
    {{ dbt_utils.generate_surrogate_key(['t1.proposicao_id_nk']) }} AS sk_proposicao_ecidadania,
    t1.*,
    COALESCE(t2.proposicao_id_nk IS NOT NULL, FALSE)::BOOLEAN       AS flag_mais_votado_no_dia
FROM proposicoes AS t1
LEFT JOIN mais_votados AS t2
    ON t1.proposicao_id_nk = t2.proposicao_id_nk AND t1.data_extracao = t2.data_extracao
