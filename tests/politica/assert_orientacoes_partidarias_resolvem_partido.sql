{{ config(tags=["politica"]) }}

-- Orientação de liderança partidária da Câmara precisa apontar para uma entidade de dim_partidos.
SELECT
    casa,
    votacao_id_nk,
    sigla_lideranca
FROM {{ ref('int_orientacoes_unificadas') }}
WHERE
    casa = 'CAMARA'
    AND tipo_lideranca = 'PARTIDO'
    AND partido_id_senado IS NULL
