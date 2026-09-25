{% macro parlamentar_periodo(periodo) %}
{#-
    Agregado parlamentar × período do domínio política. `periodo`: legislatura, ano, trimestre ou semana.
    Participação e presença vêm de fct_presencas_plenario (só Plenário); governismo, disciplina e
    votos vencedores vêm dos votos com posição em qualquer órgão.
-#}
{%- set chaves = {
    'legislatura': ['legislatura'],
    'ano': ['ano'],
    'trimestre': ['ano', 'trimestre'],
    'semana': ['inicio_semana'],
}[periodo] -%}
{%- set expressoes = {
    'legislatura': ['c.legislatura'],
    'ano': ['c.ano'],
    'trimestre': ['c.ano', 'c.trimestre_do_ano'],
    'semana': ['c.inicio_semana'],
}[periodo] -%}

WITH
calendario AS (
    SELECT
        c.data_sk,
        c.data,
        {% for chave in chaves -%}
            {{ expressoes[loop.index0] }} AS {{ chave }}{{ "," if not loop.last }}
        {% endfor %}
    FROM {{ ref('dim_calendario_legislativo') }} AS c
    {% if is_incremental() -%}
        WHERE c.data >= {{ inicio_periodo_vivo(granularidade_periodo_vivo(periodo)) }}
    {%- endif %}
),

votos AS (
    SELECT
        v.sk_parlamentar,
        v.casa,
        {% for chave in chaves -%}
            c.{{ chave }},
        {% endfor -%}
        v.sk_partido,
        v.partido_rotulo,
        v.partido,
        v.uf,
        v.fl_seguiu_governo,
        v.fl_seguiu_partido,
        v.fl_seguiu_bancada,
        v.fl_votou_com_resultado
    FROM {{ ref('votos_parlamentares') }} AS v
    INNER JOIN calendario AS c
        ON v.data_votacao = c.data
    WHERE
        v.voto IN ('SIM', 'NAO', 'OBSTRUCAO')
        {% if is_incremental() -%}
            AND v.data_votacao >= {{ inicio_periodo_vivo(granularidade_periodo_vivo(periodo)) }}
        {%- endif %}
),

presencas AS (
    SELECT
        p.sk_parlamentar,
        p.casa,
        {% for chave in chaves -%}
            c.{{ chave }},
        {% endfor -%}
        p.sk_partido,
        p.uf,
        p.categoria_presenca,
        p.fl_presente,
        p.fl_ausencia_inferida,
        p.fl_votou_com_posicao,
        (p.modalidade_votacao = 'NOMINAL ABERTA' AND p.fl_governo_orientou = 1)::INT AS fl_elegivel
    FROM {{ ref('fct_presencas_plenario') }} AS p
    INNER JOIN calendario AS c
        ON p.sk_data = c.data_sk
    {% if is_incremental() -%}
        WHERE p.sk_data >= TO_CHAR({{ inicio_periodo_vivo(granularidade_periodo_vivo(periodo)) }}, 'YYYYMMDD')::INT
    {%- endif %}
),

metricas_votos AS (
    SELECT
        sk_parlamentar,
        casa,
        {% for chave in chaves -%}
            {{ chave }},
        {% endfor -%}
        COUNT(fl_seguiu_governo)                                 AS qt_votos_governismo,
        COALESCE(SUM(fl_seguiu_governo), 0)                      AS qt_votos_alinhados_governo,
        COUNT(fl_seguiu_partido)                                 AS qt_votos_disciplina,
        COALESCE(SUM(fl_seguiu_partido), 0)                      AS qt_votos_disciplinados,
        COUNT(fl_seguiu_bancada)                                 AS qt_votos_disciplina_bancada,
        COALESCE(SUM(fl_seguiu_bancada), 0)                      AS qt_votos_disciplinados_bancada,
        COUNT(fl_votou_com_resultado)                            AS qt_votos_com_resultado,
        COALESCE(SUM(fl_votou_com_resultado), 0)                 AS qt_votos_vencedores,
        STRING_AGG(DISTINCT partido, ', ' ORDER BY partido)      AS siglas_no_periodo
    FROM votos
    GROUP BY sk_parlamentar, casa, {{ chaves | join(', ') }}
),

metricas_presencas AS (
    SELECT
        sk_parlamentar,
        casa,
        {% for chave in chaves -%}
            {{ chave }},
        {% endfor -%}
        COUNT(*)                                                                    AS qt_votacoes_nominais_elegiveis,
        COUNT(*) FILTER (WHERE fl_presente = 1)                                     AS qt_presencas,
        COUNT(*) FILTER (WHERE fl_presente IS NOT NULL)                             AS qt_presencas_informadas,
        COUNT(*) FILTER (WHERE categoria_presenca = 'AUSENCIA JUSTIFICADA')         AS qt_ausencias_justificadas,
        COUNT(*) FILTER (WHERE categoria_presenca = 'AUSENCIA NAO JUSTIFICADA')     AS qt_ausencias_nao_justificadas,
        COUNT(*) FILTER (WHERE fl_ausencia_inferida = 1)                            AS qt_ausencias_inferidas,
        COUNT(*) FILTER (WHERE fl_elegivel = 1)                                     AS qt_votacoes_elegiveis,
        COUNT(*) FILTER (WHERE fl_elegivel = 1 AND fl_votou_com_posicao = 1)        AS qt_votacoes_participadas
    FROM presencas
    GROUP BY sk_parlamentar, casa, {{ chaves | join(', ') }}
),

-- UF e partido do período: os de mais votos, com desempate alfabético.
uf_predominante AS (
    SELECT DISTINCT ON (sk_parlamentar, {{ chaves | join(', ') }})
        sk_parlamentar,
        {% for chave in chaves -%}
            {{ chave }},
        {% endfor -%}
        uf
    FROM votos
    GROUP BY sk_parlamentar, {{ chaves | join(', ') }}, uf
    ORDER BY sk_parlamentar, {{ chaves | join(', ') }}, COUNT(*) DESC, uf ASC
),

partido_predominante AS (
    SELECT DISTINCT ON (sk_parlamentar, {{ chaves | join(', ') }})
        sk_parlamentar,
        {% for chave in chaves -%}
            {{ chave }},
        {% endfor -%}
        sk_partido,
        partido_rotulo
    FROM votos
    WHERE sk_partido <> '{{ var("null_key") }}'
    GROUP BY sk_parlamentar, {{ chaves | join(', ') }}, sk_partido, partido_rotulo
    ORDER BY sk_parlamentar, {{ chaves | join(', ') }}, COUNT(*) DESC, partido_rotulo ASC
),

-- Sem voto com posição no período (ex.: só votações secretas), vale o registro de presença.
uf_presencas AS (
    SELECT DISTINCT ON (sk_parlamentar, {{ chaves | join(', ') }})
        sk_parlamentar,
        {% for chave in chaves -%}
            {{ chave }},
        {% endfor -%}
        uf
    FROM presencas
    WHERE uf <> '{{ var("null_string") }}'
    GROUP BY sk_parlamentar, {{ chaves | join(', ') }}, uf
    ORDER BY sk_parlamentar, {{ chaves | join(', ') }}, COUNT(*) DESC, uf ASC
),

partido_presencas AS (
    SELECT DISTINCT ON (sk_parlamentar, {{ chaves | join(', ') }})
        pr.sk_parlamentar,
        {% for chave in chaves -%}
            pr.{{ chave }},
        {% endfor -%}
        pr.sk_partido,
        dp.rotulo AS partido_rotulo
    FROM presencas AS pr
    INNER JOIN {{ ref('dim_partidos') }} AS dp
        ON pr.sk_partido = dp.sk_partido
    WHERE pr.sk_partido <> '{{ var("null_key") }}'
    GROUP BY pr.sk_parlamentar, {% for chave in chaves %}pr.{{ chave }}, {% endfor %}pr.sk_partido, dp.rotulo
    ORDER BY pr.sk_parlamentar, {% for chave in chaves %}pr.{{ chave }}, {% endfor %}COUNT(*) DESC, dp.rotulo ASC
),

chaves AS (
    SELECT sk_parlamentar, casa, {{ chaves | join(', ') }} FROM metricas_votos
    UNION
    SELECT sk_parlamentar, casa, {{ chaves | join(', ') }} FROM metricas_presencas
),

final AS (
    SELECT
        k.sk_parlamentar,
        d.deputado_id_nk,
        d.senador_id_nk,
        k.casa,
        d.nome,
        d.sexo,
        {% for chave in chaves -%}
            k.{{ chave }},
        {% endfor -%}
        {%- if periodo == 'legislatura' %}
        l.inicio                                                                               AS periodo_inicio,
        l.fim                                                                                  AS periodo_fim,
        {%- elif periodo == 'ano' %}
        MAKE_DATE(k.ano::INT, 1, 1)                                                            AS periodo_inicio,
        MAKE_DATE(k.ano::INT, 12, 31)                                                          AS periodo_fim,
        {%- elif periodo == 'trimestre' %}
        MAKE_DATE(k.ano::INT, (k.trimestre::INT - 1) * 3 + 1, 1)                               AS periodo_inicio,
        (MAKE_DATE(k.ano::INT, (k.trimestre::INT - 1) * 3 + 1, 1) + INTERVAL '3 months')::DATE - 1
            AS periodo_fim,
        {%- else %}
        k.inicio_semana                                                                        AS periodo_inicio,
        k.inicio_semana + 6                                                                    AS periodo_fim,
        {%- endif %}
        COALESCE(u.uf, up.uf)                                                                  AS uf,
        r.regiao,
        COALESCE(p.sk_partido, pp.sk_partido)                                                  AS sk_partido,
        COALESCE(p.partido_rotulo, pp.partido_rotulo)                                          AS partido,
        v.siglas_no_periodo,
        COALESCE(e.qt_votacoes_nominais_elegiveis, 0)                                          AS qt_votacoes_nominais_elegiveis,
        COALESCE(e.qt_presencas, 0)                                                            AS qt_presencas,
        ROUND(100.0 * e.qt_presencas / NULLIF(e.qt_presencas_informadas, 0), 2)                AS presenca_pct,
        COALESCE(e.qt_ausencias_justificadas, 0)                                               AS qt_ausencias_justificadas,
        COALESCE(e.qt_ausencias_nao_justificadas, 0)                                           AS qt_ausencias_nao_justificadas,
        COALESCE(e.qt_ausencias_inferidas, 0)                                                  AS qt_ausencias_inferidas,
        COALESCE(e.qt_votacoes_elegiveis, 0)                                                   AS qt_votacoes_elegiveis,
        COALESCE(e.qt_votacoes_participadas, 0)                                                AS qt_votacoes_participadas,
        ROUND(100.0 * e.qt_votacoes_participadas / NULLIF(e.qt_votacoes_elegiveis, 0), 2)     AS participacao_pct,
        COALESCE(v.qt_votos_governismo, 0)                                                     AS qt_votos_governismo,
        COALESCE(v.qt_votos_alinhados_governo, 0)                                              AS qt_votos_alinhados_governo,
        ROUND(100.0 * v.qt_votos_alinhados_governo / NULLIF(v.qt_votos_governismo, 0), 2)      AS governismo_pct_modelo,
        COALESCE(v.qt_votos_disciplina, 0)                                                     AS qt_votos_disciplina,
        COALESCE(v.qt_votos_disciplinados, 0)                                                  AS qt_votos_disciplinados,
        ROUND(100.0 * v.qt_votos_disciplinados / NULLIF(v.qt_votos_disciplina, 0), 2)          AS disciplina_pct,
        COALESCE(v.qt_votos_disciplina_bancada, 0)                                             AS qt_votos_disciplina_bancada,
        COALESCE(v.qt_votos_disciplinados_bancada, 0)                                          AS qt_votos_disciplinados_bancada,
        ROUND(100.0 * v.qt_votos_disciplinados_bancada / NULLIF(v.qt_votos_disciplina_bancada, 0), 2)
            AS disciplina_bancada_pct,
        COALESCE(v.qt_votos_com_resultado, 0)                                                  AS qt_votos_com_resultado,
        COALESCE(v.qt_votos_vencedores, 0)                                                     AS qt_votos_vencedores,
        ROUND(100.0 * v.qt_votos_vencedores / NULLIF(v.qt_votos_com_resultado, 0), 2)         AS votos_vencedores_pct,
        '{{ run_started_at }}'::TIMESTAMPTZ                                                    AS model_run_at
    FROM chaves AS k
    LEFT JOIN metricas_votos AS v
        ON k.sk_parlamentar = v.sk_parlamentar
        {%- for chave in chaves %}
        AND k.{{ chave }} = v.{{ chave }}
        {%- endfor %}
    LEFT JOIN metricas_presencas AS e
        ON k.sk_parlamentar = e.sk_parlamentar
        {%- for chave in chaves %}
        AND k.{{ chave }} = e.{{ chave }}
        {%- endfor %}
    LEFT JOIN uf_predominante AS u
        ON k.sk_parlamentar = u.sk_parlamentar
        {%- for chave in chaves %}
        AND k.{{ chave }} = u.{{ chave }}
        {%- endfor %}
    LEFT JOIN partido_predominante AS p
        ON k.sk_parlamentar = p.sk_parlamentar
        {%- for chave in chaves %}
        AND k.{{ chave }} = p.{{ chave }}
        {%- endfor %}
    LEFT JOIN uf_presencas AS up
        ON k.sk_parlamentar = up.sk_parlamentar
        {%- for chave in chaves %}
        AND k.{{ chave }} = up.{{ chave }}
        {%- endfor %}
    LEFT JOIN partido_presencas AS pp
        ON k.sk_parlamentar = pp.sk_parlamentar
        {%- for chave in chaves %}
        AND k.{{ chave }} = pp.{{ chave }}
        {%- endfor %}
    LEFT JOIN {{ ref('dim_parlamentares') }} AS d
        ON k.sk_parlamentar = d.sk_parlamentar
    LEFT JOIN {{ ref('dim_uf') }} AS r
        ON COALESCE(u.uf, up.uf) = r.uf
    {%- if periodo == 'legislatura' %}
    LEFT JOIN {{ ref('dim_legislatura') }} AS l
        ON k.legislatura = l.legislatura
    {%- endif %}
)

SELECT * FROM final
{% endmacro %}

{% macro granularidade_periodo_vivo(periodo) %}
    {{- return({'legislatura': 'legislatura', 'ano': 'year', 'trimestre': 'quarter', 'semana': 'week'}[periodo]) -}}
{% endmacro %}
