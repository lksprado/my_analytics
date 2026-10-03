{{
  config(
    tags = ['financas', 'marts'],
  )
}}

{#- Camada é estado atual, não SCD2: a planilha perdeu mes_base, então um mês
    passado carrega a classificação de hoje.

    A chave do join inclui instituicao: BRSTNCLTN806 da Deusa está no Banco do
    Brasil e no Nubank, e sem ela a posição duplica.

    fonte_dado vem de cada trilha (relatório, seed, planilha), porque depois do
    UNION ALL a origem não é recuperável. -#}

WITH
fgc AS (
    SELECT * FROM {{ ref('stg_de_para_instituicoes_fgc') }}
),

datas AS (
    SELECT DISTINCT
        inicio_mes,
        fim_mes,
        trimestre_do_ano,
        ano
    FROM {{ ref('dim_datas') }}
),

posicoes AS (
    SELECT
        mes_base,
        pessoa,
        instituicao,
        emissor,
        classe_ativo,
        tipo_ativo,
        codigo_ativo,
        ativo,
        indexador,
        data_vencimento,
        vencimento_em_dias,
        fl_vencido,
        vlr_atualizado_brl,
        moeda_ativo,
        fonte_dado
    FROM {{ ref('int_investimentos_consolidados') }}
),

-- emissor é o banco da conta, para o de-para do FGC agrupar a conta com os títulos do mesmo conglomerado.
saldos AS (
    SELECT
        COALESCE(t1.mes_base, t2.mes_base) AS mes_base,
        v.pessoa,
        v.instituicao,
        v.emissor,
        'DISPONIBILIDADE'                  AS classe_ativo,
        'CONTA CORRENTE'                   AS tipo_ativo,
        v.codigo_ativo,
        'SALDO EM CONTA'                   AS ativo,
        NULL::TEXT                         AS indexador,
        NULL::DATE                         AS data_vencimento,
        NULL::INT                          AS vencimento_em_dias,
        NULL::BOOLEAN                      AS fl_vencido,
        v.vlr_atualizado_brl,
        v.moeda_ativo,
        'GOOGLE SHEETS'                    AS fonte_dado
    FROM {{ ref('stg_patrimonio') }} AS t1
    FULL JOIN {{ ref('stg_patrimonio_deusa') }} AS t2
        ON t1.mes_base = t2.mes_base
    CROSS JOIN LATERAL (
        VALUES
            ('lucas',   'BRADESCO',        'BANCO BRADESCO',  'BRDCONTALCS', 'BRL', COALESCE(t1.saldo_bradesco_lucas, 0)),
            ('lucas',   'NUBANK',          'NUBANK',          'NUBCONTALCS', 'BRL', COALESCE(t1.saldo_nubank_lucas, 0)),
            ('lucas',   'NUBANK',          'NUBANK',          'NUBCASHLCS',  'BRL', COALESCE(t1.saldo_nubank_cashback_lucas, 0)),
            ('lucas',   'WISE',            NULL,              'WISCONTALCS', 'USD', COALESCE(t1.saldo_wise_lucas, 0)),
            ('lucas',   'AUTOCUSTODIA',    NULL,              'BTCCONTALCS', 'BTC', COALESCE(t1.saldo_bitcoin_lucas, 0)),
            ('jessica', 'BANCO DO BRASIL', 'BANCO DO BRASIL', 'BBCONTAJSS',  'BRL', COALESCE(t1.saldo_banco_brasil_jessica, 0)),
            ('jessica', 'NUBANK',          'NUBANK',          'NUBCONTAJSS', 'BRL', COALESCE(t1.saldo_nubank_jessica, 0)),
            ('deusa',   'BRADESCO',        'BANCO BRADESCO',  'BRDCONTADEU', 'BRL', COALESCE(t2.saldo_bradesco_deusa, 0)),
            ('deusa',   'BANCO DO BRASIL', 'BANCO DO BRASIL', 'BBCONTADEU',  'BRL', COALESCE(t2.saldo_banco_brasil_deusa, 0)),
            ('deusa',   'NUBANK',          'NUBANK',          'NUBCONTADEU', 'BRL', COALESCE(t2.saldo_nubank_deusa, 0)),
            ('deusa',   'NUBANK',          'NUBANK',          'NUBCASHDEU',  'BRL', COALESCE(t2.saldo_nubank_cashback_deusa, 0))
    ) AS v (pessoa, instituicao, emissor, codigo_ativo, moeda_ativo, vlr_atualizado_brl)
    -- O staging troca célula vazia por 0; sem o filtro, toda conta de todo mês vira posição zerada.
    WHERE v.vlr_atualizado_brl <> 0
),

classificacao AS (
    SELECT
        pessoa,
        codigo_ativo,
        instituicao,
        camada
    FROM {{ ref('stg_carteira_classificacao') }}
),

unioned AS (
    SELECT * FROM posicoes
    UNION ALL
    SELECT * FROM saldos
),

final AS (
    SELECT
        t1.mes_base,
        t2.fim_mes                              AS mes_final,
        t2.trimestre_do_ano                     AS trimestre,
        t2.ano,
        t1.pessoa,
        t1.instituicao,
        t1.emissor,
        CASE 
            WHEN t4.conglomerado IS NULL AND t1.emissor = 'TESOURO NACIONAL'
                THEN 'TESOURO NACIONAL'
            WHEN t4.conglomerado IS NOT NULL
                THEN t4.conglomerado
            ELSE 'NAO APLICAVEL'
        END AS conglomerado_fgc,
        t1.classe_ativo,
        t1.tipo_ativo,
        t1.codigo_ativo,
        t1.ativo,
        t1.indexador,
        t1.data_vencimento,
        t1.vencimento_em_dias,
        t1.fl_vencido,
        t1.vlr_atualizado_brl,
        t1.moeda_ativo,
        t1.fonte_dado,
        COALESCE(t3.camada, 'NAO CLASSIFICADO') AS camada,
        t1.mes_base = MAX(t1.mes_base) OVER ()  AS fl_mes_atual
    FROM unioned AS t1
    INNER JOIN datas AS t2
        ON t1.mes_base = t2.inicio_mes
    LEFT JOIN classificacao AS t3
        ON t1.pessoa = t3.pessoa
        AND t1.codigo_ativo = t3.codigo_ativo
        AND t1.instituicao = t3.instituicao
    LEFT JOIN fgc AS t4
        ON t1.emissor = t4.instituicao
)

SELECT
    final.*,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM final
ORDER BY final.mes_base, final.pessoa, final.instituicao, final.classe_ativo, final.tipo_ativo, final.ativo
