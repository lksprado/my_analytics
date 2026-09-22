{{ config(
    tags=["camara", "senado", "votacoes"]
) }}

WITH
votos AS (
    SELECT
        casa,
        deputado_id_nk AS parlamentar_id_nk,
        votacao_id_fk,
        partido,
        partido_nome,
        voto
    FROM {{ ref('int_votos_camara_filtrados') }}
    UNION ALL
    SELECT
        casa,
        senador_id_nk,
        votacao_id_fk::TEXT,
        partido,
        partido_nome,
        voto
    FROM {{ ref('int_votos_senado_filtrados') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['casa', 'parlamentar_id_nk', 'votacao_id_fk']) }} AS sk_voto,
    CASE
        WHEN parlamentar_id_nk IS NULL THEN '{{ var("null_key") }}'
        ELSE {{ dbt_utils.generate_surrogate_key(['casa', 'parlamentar_id_nk']) }}
    END                                                                                    AS sk_parlamentar,
    {{ dbt_utils.generate_surrogate_key(['casa', 'votacao_id_fk']) }}                      AS sk_votacao,
    votacao_id_fk                                                                          AS votacao_id_nk,
    casa,
    partido,
    partido_nome,
    voto,
    '{{ run_started_at }}'::TIMESTAMPTZ                                                    AS model_run_at
FROM votos
