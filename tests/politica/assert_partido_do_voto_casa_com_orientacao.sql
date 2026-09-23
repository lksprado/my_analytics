{{ config(tags=["politica"]) }}

-- Sigla igual na mesma votação exige entidade igual (pega id trocado em seed_partidos).
SELECT
    v.casa,
    v.votacao_id_nk,
    v.partido,
    v.partido_id_senado AS entidade_voto,
    o.partido_id_senado AS entidade_orientacao,
    COUNT(*)            AS qt_votos
FROM {{ ref('int_votos_unificados') }} AS v
INNER JOIN {{ ref('int_orientacoes_unificadas') }} AS o
    ON
    v.casa = o.casa
    AND v.votacao_id_nk = o.votacao_id_nk
    AND v.partido = o.sigla_lideranca
WHERE v.partido_id_senado IS DISTINCT FROM o.partido_id_senado
GROUP BY 1, 2, 3, 4, 5
