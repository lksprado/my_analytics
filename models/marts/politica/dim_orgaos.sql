{{ config(
    tags=["politica"]
) }}

WITH
orgaos AS (
    SELECT DISTINCT
        casa,
        sigla_orgao
    FROM {{ ref('int_votacoes_unificadas') }}
    WHERE sigla_orgao IS NOT NULL
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['casa', 'sigla_orgao']) }} AS sk_orgao,
        casa,
        sigla_orgao,
        -- Comissão especial leva o número da proposição na sigla.
        CASE
            WHEN sigla_orgao = 'PLEN' THEN 'PLENARIO'
            WHEN sigla_orgao = 'MESA' THEN 'MESA DIRETORA'
            WHEN sigla_orgao ~ '^CPM?I' THEN 'CPI'
            WHEN sigla_orgao ~ '^(PEC|PLP|PLV|PL|MPV|PDL|PDC|PRC)[0-9]' THEN 'COMISSAO ESPECIAL'
            WHEN sigla_orgao ~ '^C' THEN 'COMISSAO'
            ELSE 'OUTROS'
        END                                                             AS tipo_orgao,
        '{{ run_started_at }}'::TIMESTAMPTZ                             AS model_run_at
    FROM orgaos
)

SELECT * FROM final
UNION ALL
{{ dummy_row([
    ['sk_orgao', 'sk'],
    ['casa', 'text'],
    ['sigla_orgao', 'text'],
    ['tipo_orgao', 'text'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
