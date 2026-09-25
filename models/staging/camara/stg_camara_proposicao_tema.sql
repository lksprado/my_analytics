{{ config(
    tags=["politica"]
) }}


WITH
source AS (
    SELECT
        'API'     AS origem,
        url_temas AS uri_proposicao,
        tema,
        codtema,
        relevancia,
        loaded_at_utc
    FROM {{ source('camara','raw_camara_proposicao_tema') }}
),

source_arquivo AS (
    SELECT
        'ARQUIVO'     AS origem,
        uriproposicao AS uri_proposicao,
        tema,
        codtema,
        relevancia,
        loaded_at_utc
    FROM {{ source('camara','arquivo_proposicoes_temas') }}
),

source_unioned AS (
    SELECT * FROM source
    UNION ALL
    SELECT * FROM source_arquivo
),

-- O arquivo anual contém os temas da API e repete pares: fica a carga mais recente.
deduplicada AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY SPLIT_PART(uri_proposicao, '/', 7), codtema
            ORDER BY loaded_at_utc DESC, (origem = 'API') DESC
        ) AS rn
    FROM source_unioned
),

renamed AS (
    SELECT
        SPLIT_PART(uri_proposicao, '/', 7)  AS proposicao_id_nk,
        {{ clean_string("tema", "upper") }} AS tema,
        codtema::BIGINT                     AS codigo_tema,
        relevancia::INT                     AS relevancia,
        origem,
        loaded_at_utc,
        '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
    FROM deduplicada
    WHERE rn = 1
)

SELECT * FROM renamed
