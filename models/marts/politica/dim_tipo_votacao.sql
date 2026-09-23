{{ config(
    tags=["politica"]
) }}

WITH
classes (classe_votacao, grupo_votacao) AS (
    VALUES
    ('MERITO', 'MERITO'),
    ('EMENDA/DESTAQUE', 'MERITO'),
    ('URGENCIA', 'PROCEDIMENTAL'),
    ('REQUERIMENTO PROCEDIMENTAL', 'PROCEDIMENTAL'),
    ('PARECER', 'ADMISSIBILIDADE'),
    ('AUTORIDADE', 'AUTORIDADE'),
    ('OUTROS', 'OUTROS')
),

indicadores (flag) AS (
    VALUES (0), (1)
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['c.classe_votacao', 'n.flag', 's.flag']) }} AS sk_tipo_votacao,
        c.classe_votacao,
        c.grupo_votacao,
        n.flag                                                                           AS fl_nominal,
        s.flag                                                                           AS fl_secreta,
        '{{ run_started_at }}'::TIMESTAMPTZ                                              AS model_run_at
    FROM classes AS c
    CROSS JOIN indicadores AS n
    CROSS JOIN indicadores AS s
)

SELECT * FROM final
UNION ALL
{{ dummy_row([
    ['sk_tipo_votacao', 'sk'],
    ['classe_votacao', 'text'],
    ['grupo_votacao', 'text'],
    ['fl_nominal', 'null::int'],
    ['fl_secreta', 'null::int'],
    ['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"],
]) }}
