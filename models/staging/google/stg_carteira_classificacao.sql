{{
  config(
    materialized = 'table',
    tags = ['financas', 'staging'],
  )
}}

{#- A aba "classificacao" da planilha é um cadastro de ESTADO ATUAL: uma linha por
    ativo que se tem hoje, sem coluna de vigência. Ela já teve `mes_base`, e
    int_carteira resolvia a camada com um join as-of (SCD2) contra essa data.
    A coluna saiu da origem, então não há mais o que datar: o lookup é direto e
    meses passados carregam a classificação de hoje.

    A chave é pessoa + codigo_ativo + instituicao. Só codigo_ativo não basta —
    BRSTNCLTN806 da Deusa está cadastrado no Banco do Brasil e no Nubank, e o
    join sem instituição duplicaria a posição. -#}

WITH
source AS (
    SELECT * FROM {{ source('raw','carteira_classificacao') }}
),

renamed AS (
    SELECT
        pessoa,
        instituicao,
        classe_ativo,
        codigo_ativo,
        ativo,
        {#- data_vencimento chega como texto e vem vazia na maioria das linhas
            (renda variável e conta corrente não vencem); '' não é castável. -#}
        NULLIF(TRIM(data_vencimento), '')::DATE AS data_vencimento,
        moeda_ativo,
        camada
    FROM source
)

SELECT * FROM renamed
