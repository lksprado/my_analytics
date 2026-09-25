{{ config(tags=["politica"]) }}

-- As agregadas de governismo são somas das flags de fct_votos.
WITH
atomico AS (
    SELECT
        SUM(fl_seguiu_governo)   AS qt_alinhados,
        COUNT(fl_seguiu_governo) AS qt_votos
    FROM {{ ref('fct_votos') }}
    WHERE sk_parlamentar <> '{{ var("null_key") }}'
),

legislatura AS (
    SELECT
        SUM(qt_votos_alinhados_governo) AS qt_alinhados,
        SUM(qt_votos_governismo)        AS qt_votos
    FROM {{ ref('fct_governismo_legislatura') }}
),

trimestre AS (
    SELECT
        SUM(qt_votos_alinhados_governo) AS qt_alinhados,
        SUM(qt_votos_governismo)        AS qt_votos
    FROM {{ ref('fct_governismo_trimestre') }}
)

SELECT
    a.qt_alinhados AS atomico_alinhados,
    l.qt_alinhados AS legislatura_alinhados,
    t.qt_alinhados AS trimestre_alinhados,
    a.qt_votos     AS atomico_votos,
    l.qt_votos     AS legislatura_votos,
    t.qt_votos     AS trimestre_votos
FROM atomico AS a
CROSS JOIN legislatura AS l
CROSS JOIN trimestre AS t
WHERE
    a.qt_alinhados <> l.qt_alinhados
    OR a.qt_alinhados <> t.qt_alinhados
    OR a.qt_votos <> l.qt_votos
    OR a.qt_votos <> t.qt_votos
