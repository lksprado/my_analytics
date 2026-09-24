{{ config(
    tags=["politica"]
) }}


WITH
senado_votacoes AS (
    SELECT
        *,
        'SENADO' AS casa
    FROM {{ ref('stg_senado_votacoes') }}
),

final AS (
    SELECT
        casa,
        votacao_id_nk,
        codigo_sessao::TEXT                              AS sessao_id,
        processo_id_nk,
        data_votacao,
        sigla,
        numero,
        identificacao,
        sigla_colegiado,
        {{ clean_string("descricao_votacao", "upper") }} AS descricao,
        (votacao_secreta = 'SIM')::INT                   AS fl_secreta,
        aprovado,
        '{{ run_started_at }}'::TIMESTAMPTZ              AS model_run_at
    FROM senado_votacoes
    ORDER BY data_votacao DESC

)

SELECT * FROM final
