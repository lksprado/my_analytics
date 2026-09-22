{{ config(
    tags=["camara", "senado", "votacoes"]
) }}

WITH
votos_deputados AS (
    SELECT
        t1.casa,
        t2.sk_parlamentar,
        t1.deputado_id_nk,
        0                  AS senador_id_nk,
        t1.votacao_id_fk,
        t1.partido,
        t1.partido_nome,
        t1.voto
    FROM {{ ref('int_votos_camara_filtrados') }} t1 
        LEFT JOIN {{ ref('dim_parlamentares') }} t2 
            ON t1.deputado_id_nk = t2.deputado_id_nk
),
votos_senadores AS (
    SELECT
        t1.casa,
        t2.sk_parlamentar,
        0                  AS deputado_id_NK,
        t1.senador_id_nk,
        t1.votacao_id_fk,
        t1.partido,
        t1.partido_nome,
        t1.voto
    FROM {{ ref('int_votos_senado_filtrados') }} t1
        LEFT JOIN {{ ref('dim_parlamentares') }} t2 
            ON t1.senador_id_nk = t2.senador_id_nk
),
votos_unidos AS (
    SELECT * FROM votos_deputados 
    UNION ALL 
    SELECT * FROM votos_senadores
),
final AS (
    SELECT
        t1.casa,
        t2.sk_data,
        {{ dbt_utils.generate_surrogate_key(['t1.sk_parlamentar', 't2.sk_votacao']) }} AS sk_voto,
        t2.sk_votacao,
        t1.sk_parlamentar,        
        t1.votacao_id_fk,
        t1.deputado_id_nk                                                              AS deputado_id_fk,
        t1.senador_id_nk                                                               AS senador_id_fk,
        t1.voto,
        t1.partido,
        t1.partido_nome,
        '{{ run_started_at }}'::TIMESTAMPTZ                                            AS model_run_at
    FROM votos_unidos t1 
    INNER JOIN {{ ref('dim_votacoes') }} t2
    ON t1.votacao_id_fk = t2.votacao_id_nk
    WHERE t2.sk_parlamentar IS NOT NULL 
)
SELECT * FROM final
