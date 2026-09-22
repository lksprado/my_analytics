{{ config(
    tags=["camara", "parlamentar"]
) }}

WITH
deputados AS (
    SELECT DISTINCT ON (deputado_id_nk)
        1              AS prioridade,
        deputado_id_nk AS parlamentar_id_nk,
        nome_eleitoral AS nome,
        nome_civil     AS nome_completo,
        CASE
            WHEN sexo = 'M' THEN 'MASCULINO'
            WHEN sexo = 'F' THEN 'FEMININO'
        END            AS sexo
    FROM {{ ref('stg_camara_deputados') }}
    ORDER BY deputado_id_nk
),

deputados_historico AS (
    SELECT DISTINCT ON (deputado_id_fk)
        0              AS prioridade,
        deputado_id_fk AS parlamentar_id_nk,
        nome,
        NULL           AS nome_completo,
        NULL           AS sexo
    FROM {{ ref('stg_camara_legislaturas') }}
    ORDER BY deputado_id_fk
),

-- Deputados que votaram mas não aparecem nos endpoints de detalhe nem de legislatura.
deputados_votos AS (
    SELECT DISTINCT ON (deputado_id_nk)
        -1                                  AS prioridade,
        deputado_id_nk                      AS parlamentar_id_nk,
        {{ clean_string("nome","upper") }}  AS nome,
        NULL                                AS nome_completo,
        NULL                                AS sexo
    FROM {{ ref('stg_camara_votos_deputados') }}
    WHERE deputado_id_nk IS NOT NULL
    ORDER BY deputado_id_nk, legislatura_id_fk DESC
),

-- O endpoint de detalhes só traz a UF de nascimento; a UF conformada com o Senado é a de
-- representação, que só existe no roster de legislaturas e no registro do voto.
uf_mandatos AS (
    SELECT
        deputado_id_fk    AS parlamentar_id_nk,
        legislatura_id_nk AS legislatura,
        uf
    FROM {{ ref('stg_camara_legislaturas') }}
    UNION ALL
    SELECT
        deputado_id_nk,
        legislatura_id_fk,
        uf
    FROM {{ ref('stg_camara_votos_deputados') }}
    WHERE deputado_id_nk IS NOT NULL
),

uf_representacao AS (
    SELECT DISTINCT ON (parlamentar_id_nk)
        parlamentar_id_nk,
        uf
    FROM uf_mandatos
    WHERE uf IS NOT NULL
    ORDER BY parlamentar_id_nk, legislatura DESC
),

deputados_completo AS (
    SELECT
        *,
        'CAMARA'                                                                   AS casa,
        ROW_NUMBER() OVER (PARTITION BY parlamentar_id_nk ORDER BY prioridade DESC) AS rn
    FROM (
        SELECT * FROM deputados
        UNION ALL
        SELECT * FROM deputados_historico
        UNION ALL
        SELECT * FROM deputados_votos
    )
),

deputados_radar AS (
    SELECT 
        radar_parlamentar_id_nk,
        parlamentar_id_fk,
        uf
    FROM {{ ref('stg_radarcongresso_parlamentares') }}
    WHERE casa = 'CAMARA'
),

final AS (
    SELECT
        t1.casa,
        t1.parlamentar_id_nk,
        t3.radar_parlamentar_id_nk AS radar_parlamentar_id_fk,
        t1.nome,
        t1.nome_completo,
        t1.sexo,
        COALESCE(t2.uf, t3.uf)     AS uf,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM deputados_completo AS t1
    LEFT JOIN uf_representacao AS t2
        ON t1.parlamentar_id_nk = t2.parlamentar_id_nk
    LEFT JOIN deputados_radar AS t3 
        ON t1.parlamentar_id_nk = t3.parlamentar_id_fk
    WHERE t1.rn = 1
)

SELECT * FROM final
