{{ config(
    tags=["datas"]
) }}

{#- Não lê dim_datas, que traz as datas especiais da família. -#}

SELECT * FROM {{ ref('int_dates') }}
ORDER BY data_sk
