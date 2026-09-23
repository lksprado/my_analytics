{{ config(
    tags=["politica"]
) }}


WITH
orientacoes AS (
    SELECT
        'SENADO'      AS casa,
        votacao_id_fk AS votacao_origem_id,
        data_votacao,
        numero_materia,
        sigla_tipo_materia,
        total_votos_favor,
        total_votos_contra,
        partido,
        orientacao_voto
    FROM {{ ref('stg_senado_votos_orientacao') }}
    WHERE orientacao_voto IS NOT NULL
),

-- A chave do endpoint de orientação é outro espaço: a votação sai da matéria votada no dia.
votacoes_orientadas AS (
    SELECT DISTINCT
        votacao_origem_id,
        data_votacao,
        sigla_tipo_materia,
        numero_materia,
        total_votos_favor,
        total_votos_contra
    FROM orientacoes
),

placar AS (
    SELECT
        votacao_id_nk,
        COUNT(*) FILTER (WHERE voto = 'SIM') AS qt_sim,
        COUNT(*) FILTER (WHERE voto = 'NAO') AS qt_nao
    FROM {{ ref('int_votos_unificados') }}
    WHERE casa = 'SENADO'
    GROUP BY votacao_id_nk
),

candidatas AS (
    SELECT
        t1.votacao_origem_id,
        t2.votacao_id_nk,
        t3.qt_sim IS NOT NULL                                                  AS fl_placar_conhecido,
        t3.qt_sim = t1.total_votos_favor AND t3.qt_nao = t1.total_votos_contra AS fl_placar_bate
    FROM votacoes_orientadas AS t1
    INNER JOIN {{ ref('int_votacoes_senado_filtradas') }} AS t2
        ON
        t1.data_votacao = t2.data_votacao
        AND t1.sigla_tipo_materia = t2.sigla
        AND t1.numero_materia::TEXT = t2.numero
    LEFT JOIN placar AS t3
        ON t2.votacao_id_nk::TEXT = t3.votacao_id_nk
),

-- Vale a única candidata cujo placar SIM/NÃO bate; sem placar dos votos, só a candidata única.
resolvidas AS (
    SELECT
        votacao_origem_id,
        CASE
            WHEN COUNT(*) FILTER (WHERE fl_placar_bate) = 1
                THEN MIN(votacao_id_nk) FILTER (WHERE fl_placar_bate)
            WHEN COUNT(*) = 1 AND NOT BOOL_OR(fl_placar_conhecido)
                THEN MIN(votacao_id_nk)
        END AS votacao_id_fk
    FROM candidatas
    GROUP BY votacao_origem_id
),

-- Duas votações orientadas não podem cair na mesma votação: na dúvida, nenhuma fica.
unicas AS (
    SELECT
        votacao_origem_id,
        votacao_id_fk
    FROM resolvidas
    WHERE votacao_id_fk IN (
            SELECT votacao_id_fk
            FROM resolvidas
            WHERE votacao_id_fk IS NOT NULL
            GROUP BY votacao_id_fk
            HAVING COUNT(*) = 1
        )
)

SELECT
    t1.casa,
    t2.votacao_id_fk,
    t1.votacao_origem_id,
    t1.data_votacao,
    t1.numero_materia,
    t1.sigla_tipo_materia,
    t1.partido,
    t1.orientacao_voto,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM orientacoes AS t1
LEFT JOIN unicas AS t2
    ON t1.votacao_origem_id = t2.votacao_origem_id
