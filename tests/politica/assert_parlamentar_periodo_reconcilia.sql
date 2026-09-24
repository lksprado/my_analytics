{{ config(tags=["politica"]) }}

-- Todo agregado por período soma exatamente os fatos atômicos, sem dupla contagem.
WITH
atomico AS (
    SELECT
        COUNT(fl_seguiu_governo) AS qt_governismo,
        SUM(fl_seguiu_governo)   AS qt_alinhados,
        COUNT(fl_seguiu_partido) AS qt_disciplina
    FROM {{ ref('fct_votos') }}
    WHERE sk_parlamentar <> '{{ var("null_key") }}'
),

presencas AS (
    SELECT
        COUNT(*)                                         AS qt_nominais,
        COUNT(*) FILTER (WHERE fl_ausencia_inferida = 1) AS qt_inferidas
    FROM {{ ref('fct_presencas_plenario') }}
),

periodos AS (
    {% for periodo in ['legislatura', 'ano', 'trimestre', 'semana'] %}
        SELECT
            '{{ periodo }}'                     AS periodo,
            SUM(qt_votos_governismo)            AS qt_governismo,
            SUM(qt_votos_alinhados_governo)     AS qt_alinhados,
            SUM(qt_votos_disciplina)            AS qt_disciplina,
            SUM(qt_votacoes_nominais_elegiveis) AS qt_nominais,
            SUM(qt_ausencias_inferidas)         AS qt_inferidas
        FROM {{ ref('parlamentar_' ~ periodo) }}
        {% if not loop.last %}UNION ALL{% endif %}
    {% endfor %}
)

SELECT p.*
FROM periodos AS p
CROSS JOIN atomico AS a
CROSS JOIN presencas AS r
WHERE
    p.qt_governismo <> a.qt_governismo
    OR p.qt_alinhados <> a.qt_alinhados
    OR p.qt_disciplina <> a.qt_disciplina
    OR p.qt_nominais <> r.qt_nominais
    OR p.qt_inferidas <> r.qt_inferidas
