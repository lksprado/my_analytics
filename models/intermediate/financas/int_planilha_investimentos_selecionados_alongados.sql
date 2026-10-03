{{
  config(
    tags = ['financas', 'intermediate'],
  )
}}

WITH
alongado AS (
    SELECT
        s.mes_base,
        v.pessoa,
        v.instituicao,
        v.vlr_declarado_brl,
        s.fonte_dado
    FROM {{ ref('int_planilha_investimentos_selecionados') }} AS s
    CROSS JOIN LATERAL (
        VALUES
            ('lucas',   'BRADESCO',        s.bradesco_investimentos_lucas),
            ('lucas',   'NUBANK',          s.nubank_investimentos_lucas),
            ('lucas',   'AVENUE',          s.avenue_lucas),
            ('lucas',   'DAYCOVAL',        s.daycoval_lucas),
            ('jessica', 'SOFISA',          s.sofisa_investimentos_jessica),
            ('jessica', 'ITAU',            s.itau_investimentos_jessica),
            ('jessica', 'NUBANK',          s.nubank_investimentos_jessica),
            ('jessica', 'AVENUE',          s.avenue_jessica),
            ('deusa',   'BRADESCO',        s.bradesco_investimentos_deusa),
            ('deusa',   'BANCO DO BRASIL', s.banco_brasil_investimentos_deusa),
            ('deusa',   'NUBANK',          s.nubank_investimentos_deusa)
    ) AS v (pessoa, instituicao, vlr_declarado_brl)
)

SELECT
    *,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM alongado
ORDER BY mes_base, pessoa, instituicao
