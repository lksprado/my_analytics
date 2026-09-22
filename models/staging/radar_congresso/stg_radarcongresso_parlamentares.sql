{{ config(
    tags=["stg","radar","parlamentar"]
) }}


WITH source AS (
    SELECT *
    FROM {{ source('radar','raw_radar_parlamentares') }}
),

-- idparlamentarvoz é a chave usada nas tabelas de governismo; idparlamentar é o id oficial da
-- Câmara ou do Senado, com o prefixo 1 para deputado e 2 para senador.
renamed AS (
    SELECT
        idparlamentarvoz::INT               AS id_parlamentar_radar,
        idparlamentar::INT                  AS id_parlamentar_congresso,
        nomeeleitoral                       AS nome_eleitoral,
        uf,
        emexercicio::BOOLEAN                AS is_ativo,
        CASE
            WHEN casa LIKE 'camara' THEN 'CAMARA'
            WHEN casa LIKE 'senado' THEN 'SENADO'
        END                                 AS casa,
        parlamentarpartido                  AS partido_dict,
        nomeprocessado                      AS nome_completo,
        arquivo_origem,
        loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM source
)

SELECT * FROM renamed
