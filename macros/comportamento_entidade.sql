{% macro comportamento_entidade(entidade) %}
{#-
    Comportamento de um agrupamento de parlamentares por casa × período × governo.
    `entidade`: partido (entidade partidária do voto) ou bancada (federação ou bloco do partido).
-#}
{%- set chave = {'partido': 'sk_partido', 'bancada': 'sk_bancada'}[entidade] -%}
{%- set rotulo = {'partido': 'partido_rotulo', 'bancada': 'bancada'}[entidade] -%}
{%- set flag_disciplina = {'partido': 'fl_seguiu_partido', 'bancada': 'fl_seguiu_bancada'}[entidade] -%}
{%- set grupo = 'casa, ' ~ chave ~ ', ano, trimestre, legislatura, presidente, mandato' -%}

WITH
votos AS (
    SELECT
        casa,
        {{ chave }},
        {{ rotulo }},
        {% if entidade == 'bancada' -%}
            tipo_bancada,
        {% endif -%}
        partido,
        ano,
        trimestre,
        legislatura,
        presidente,
        mandato,
        sk_votacao,
        sk_parlamentar,
        voto,
        fl_seguiu_governo,
        {{ flag_disciplina }} AS fl_seguiu_disciplina
    FROM {{ ref('votos_parlamentares') }}
    WHERE
        {{ chave }} <> '{{ var("null_key") }}'
        AND voto IN ('SIM', 'NAO', 'OBSTRUCAO')
),

-- Rice ignora obstrução; votação com um só votante do grupo fica de fora (daria Rice 1).
rice_por_votacao AS (
    SELECT
        {{ grupo }},
        sk_votacao,
        COUNT(*) FILTER (WHERE voto IN ('SIM', 'NAO'))
            AS qt_polarizados,
        ABS(
            COUNT(*) FILTER (WHERE voto = 'SIM')
            - COUNT(*) FILTER (WHERE voto = 'NAO')
        )::NUMERIC
        / NULLIF(COUNT(*) FILTER (WHERE voto IN ('SIM', 'NAO')), 0)
            AS indice_rice
    FROM votos
    GROUP BY {{ grupo }}, sk_votacao
),

coesao AS (
    SELECT
        {{ grupo }},
        COUNT(*) FILTER (WHERE qt_polarizados >= 2)
            AS qt_votacoes_coesao,
        ROUND(AVG(indice_rice) FILTER (WHERE qt_polarizados >= 2), 4)
            AS indice_rice_medio
    FROM rice_por_votacao
    GROUP BY {{ grupo }}
),

-- Coesão não depende de orientação: cobre as duas casas.
agregado AS (
    SELECT
        {{ grupo }},
        {{ rotulo }},
        {% if entidade == 'bancada' -%}
            tipo_bancada,
        {% endif -%}
        STRING_AGG(DISTINCT partido, ', ' ORDER BY partido)
            AS siglas_no_periodo,
        COUNT(DISTINCT sk_parlamentar)
            AS qt_parlamentares,
        COUNT(DISTINCT sk_votacao)
            AS qt_votacoes,
        COUNT(*)
            AS qt_votos,
        NULLIF(COUNT(fl_seguiu_governo), 0)
            AS qt_votos_governismo,
        SUM(fl_seguiu_governo)
            AS qt_votos_alinhados_governo,
        NULLIF(COUNT(fl_seguiu_disciplina), 0)
            AS qt_votos_disciplina,
        SUM(fl_seguiu_disciplina)
            AS qt_votos_disciplinados
    FROM votos
    GROUP BY {{ grupo }}, {{ rotulo }}{{ ', tipo_bancada' if entidade == 'bancada' }}
),

final AS (
    SELECT
        t1.casa,
        t1.{{ chave }},
        t1.{{ rotulo }}
            AS {{ entidade }},
        {% if entidade == 'bancada' -%}
            t1.tipo_bancada,
        {% endif -%}
        t1.siglas_no_periodo,
        t1.legislatura,
        t1.presidente,
        t1.mandato,
        t1.ano,
        t1.trimestre,
        MAKE_DATE(t1.ano::INT, (t1.trimestre::INT - 1) * 3 + 1, 1)
            AS data_trimestre,
        t1.qt_parlamentares,
        t1.qt_votacoes,
        t1.qt_votos,
        t2.qt_votacoes_coesao,
        t2.indice_rice_medio,
        t1.qt_votos_governismo,
        t1.qt_votos_alinhados_governo,
        ROUND(100.0 * t1.qt_votos_alinhados_governo / t1.qt_votos_governismo, 2)
            AS governismo_pct_modelo,
        t1.qt_votos_disciplina,
        t1.qt_votos_disciplinados,
        ROUND(100.0 * t1.qt_votos_disciplinados / t1.qt_votos_disciplina, 2)
            AS disciplina_pct,
        '{{ run_started_at }}'::TIMESTAMPTZ
            AS model_run_at
    FROM agregado AS t1
    INNER JOIN coesao AS t2
        ON t1.casa = t2.casa
        AND t1.{{ chave }} = t2.{{ chave }}
        AND t1.ano = t2.ano
        AND t1.trimestre = t2.trimestre
        AND t1.legislatura IS NOT DISTINCT FROM t2.legislatura
        AND t1.presidente IS NOT DISTINCT FROM t2.presidente
        AND t1.mandato IS NOT DISTINCT FROM t2.mandato
)

SELECT * FROM final
{% endmacro %}
