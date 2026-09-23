{{ config(
    tags=["politica"]
) }}


WITH source AS (
    SELECT *
    FROM {{ ref('snap_radarcongresso_parlamentares') }}
),

-- idparlamentarvoz é a chave usada nas tabelas de governismo; idparlamentar é o id oficial da
-- Câmara ou do Senado, com o prefixo 1 para deputado e 2 para senador.
renamed AS (
    SELECT
        idparlamentarvoz::INT                        AS radar_parlamentar_id_nk,
        idparlamentar::INT                           AS parlamentar_id_fk,
        {{ clean_string("nomeeleitoral","upper") }}  AS nome_eleitoral,
        {{ clean_string("nomeprocessado","upper") }} AS nome_completo,
        uf,
        emexercicio::BOOLEAN                         AS is_ativo,
        CASE
            WHEN casa LIKE 'camara' THEN 'CAMARA'
            WHEN casa LIKE 'senado' THEN 'SENADO'
        END                                          AS casa,
        parlamentarpartido                           AS partido_dict,
        '{{ run_started_at }}'::TIMESTAMPTZ          AS model_run_at
    FROM source
    WHERE dbt_valid_to IS NULL
)

SELECT * FROM renamed
