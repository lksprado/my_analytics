{{ config(
    tags=["politica"]
) }}

WITH
final AS (
    SELECT
        b.sk_proposicao,
        b.sk_tema,
        t.codigo_tema,
        t.tema,
        b.relevancia,
        b.origem_tema,
        p.casa,
        p.tipo_proposicao,
        p.identificacao,
        p.ano_apresentacao,
        p.situacao_atual,
        p.qt_votacoes,
        p.qt_votacoes_aprovadas,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM {{ ref('bridge_proposicoes_temas') }} AS b
    INNER JOIN {{ ref('dim_tema') }} AS t
        ON b.sk_tema = t.sk_tema
    INNER JOIN {{ ref('proposicoes') }} AS p
        ON b.sk_proposicao = p.sk_proposicao
)

SELECT * FROM final
