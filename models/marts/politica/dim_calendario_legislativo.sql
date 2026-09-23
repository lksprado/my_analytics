{{ config(
    tags=["politica"]
) }}

{#- Recorte público de dim_datas: as datas especiais da família não entram no domínio publicável. -#}

WITH
calendario AS (
    SELECT
        data_sk,
        data,
        ano,
        semestre,
        trimestre_do_ano,
        inicio_trimestre,
        fim_trimestre,
        mes_sk,
        mes_do_ano,
        nome_mes,
        nome_mes_abrev,
        inicio_mes,
        fim_mes,
        semana_iso_do_ano,
        dia_semana_num,
        nome_dia_semana,
        nome_dia_semana_abrev,
        fl_fim_de_semana,
        fl_feriado,
        nome_feriado,
        fl_dia_util
    FROM {{ ref('dim_datas') }}
),

legislaturas AS (
    SELECT
        legislatura::INT AS legislatura,
        inicio::DATE     AS inicio,
        fim::DATE        AS fim
    FROM {{ ref('seed_legislaturas') }}
),

presidentes AS (
    SELECT
        presidente,
        mandato::INT AS mandato,
        inicio::DATE AS inicio,
        fim::DATE    AS fim
    FROM {{ ref('seed_executivo_presidente') }}
),

-- A seed encosta o fim de um mandato no início do seguinte; no dia da posse vale quem assume.
presidente_do_dia AS (
    SELECT DISTINCT ON (c.data_sk)
        c.data_sk,
        p.presidente,
        p.mandato
    FROM calendario AS c
    INNER JOIN presidentes AS p
        ON c.data BETWEEN p.inicio AND p.fim
    ORDER BY c.data_sk ASC, p.inicio DESC
),

final AS (
    SELECT
        c.*,
        l.legislatura,
        -- A sessão legislativa vai de 1º/fev a 31/jan: janeiro ainda conta como o ano anterior.
        c.ano - (c.mes_do_ano = 1)::INT - EXTRACT(YEAR FROM l.inicio)::INT + 1 AS sessao_legislativa,
        p.presidente,
        p.mandato                                                              AS mandato_presidencial,
        -- Calendário eleitoral vigente: gerais desde 1994, municipais desde 1996.
        c.ano >= 1994 AND c.ano % 4 = 2                                        AS fl_ano_eleicao_geral,
        c.ano >= 1996 AND c.ano % 4 = 0                                        AS fl_ano_eleicao_municipal,
        '{{ run_started_at }}'::TIMESTAMPTZ                                    AS model_run_at
    FROM calendario AS c
    LEFT JOIN legislaturas AS l
        ON c.data BETWEEN l.inicio AND l.fim
    LEFT JOIN presidente_do_dia AS p
        ON c.data_sk = p.data_sk
)

SELECT * FROM final
